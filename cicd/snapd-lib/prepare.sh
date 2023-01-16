#!/bin/bash

set -eux

# shellcheck source=tests/lib/snaps.sh
. "$TESTSLIB/snaps.sh"
# shellcheck source=tests/lib/pkgdb.sh
. "$TESTSLIB/pkgdb.sh"
# shellcheck source=tests/lib/state.sh
. "$TESTSLIB/state.sh"


disable_kernel_rate_limiting() {
    # kernel rate limiting hinders debugging security policy so turn it off
    echo "Turning off kernel rate-limiting"
    # TODO: we should be able to run the tests with rate limiting disabled so
    # debug output is robust, but we currently can't :(
    echo "SKIPPED: see https://forum.snapcraft.io/t/snapd-spread-tests-should-be-able-to-run-with-kernel-rate-limiting-disabled/424"
    #sysctl -w kernel.printk_ratelimit=0
}

disable_journald_rate_limiting() {
    # Disable journald rate limiting
    mkdir -p /etc/systemd/journald.conf.d
    # The RateLimitIntervalSec key is not supported on some systemd versions causing
    # the journal rate limit could be considered as not valid and discarded in consequence.
    # RateLimitInterval key is supported in old systemd versions and in new ones as well,
    # maintaining backward compatibility.
    cat <<-EOF > /etc/systemd/journald.conf.d/no-rate-limit.conf
    [Journal]
    RateLimitInterval=0
    RateLimitBurst=0
EOF
    systemctl restart systemd-journald.service
}

disable_journald_start_limiting() {
    # Disable journald start limiting
    mkdir -p /etc/systemd/system/systemd-journald.service.d
    cat <<-EOF > /etc/systemd/system/systemd-journald.service.d/no-start-limit.conf
    [Unit]
    StartLimitBurst=0
EOF
    systemctl daemon-reload
}

ensure_jq() {
    if command -v jq; then
        return
    fi

    if os.query is-core18; then
        snap install --devmode jq-core18
        snap alias jq-core18.jq jq
    elif os.query is-core20; then
        snap install --devmode --edge jq-core20
        snap alias jq-core20.jq jq
    elif os.query is-core22; then
        snap install --devmode --edge jq-core22
        snap alias jq-core22.jq jq
    else
        snap install --devmode jq
    fi
}

disable_refreshes() {
    echo "Ensure jq is available"
    ensure_jq

    echo "Modify state to make it look like the last refresh just happened"
    systemctl stop snapd.socket snapd.service
    "$TESTSTOOLS"/snapd-state prevent-autorefresh
    systemctl start snapd.socket snapd.service

    echo "Minimize risk of hitting refresh schedule"
    snap set core refresh.schedule=00:00-23:59
    snap refresh --time --abs-time | MATCH "last: 2[0-9]{3}"

    echo "Ensure jq is gone"
    snap remove --purge jq
    snap remove --purge jq-core18
    snap remove --purge jq-core20
    snap remove --purge jq-core22
}

repack_snapd_snap_with_run_mode_firstboot_tweaks() {
    local TARGET="$1"

    local UNPACK_DIR="/tmp/snapd-unpack"
    unsquashfs -no-progress -d "$UNPACK_DIR" snapd_*.snap

    # now install a unit that sets up enough so that we can connect
    cat > "$UNPACK_DIR"/lib/systemd/system/snapd.spread-tests-run-mode-tweaks.service <<'EOF'
[Unit]
Description=Tweaks to run mode for spread tests
Before=snapd.service
Documentation=man:snap(1)

[Service]
Type=oneshot
ExecStart=/usr/lib/snapd/snapd.spread-tests-run-mode-tweaks.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    # XXX: this duplicates a lot of setup_test_user_by_modify_writable()
    cat > "$UNPACK_DIR"/usr/lib/snapd/snapd.spread-tests-run-mode-tweaks.sh <<'EOF'
#!/bin/sh
set -e
# ensure we don't enable ssh in install mode or spread will get confused
if ! grep -E 'snapd_recovery_mode=(run|recover)' /proc/cmdline; then
    echo "not in run or recovery mode - script not running"
    exit 0
fi
if [ -e /root/spread-setup-done ]; then
    exit 0
fi

# extract data from previous stage
(cd / && tar xf /run/mnt/ubuntu-seed/run-mode-overlay-data.tar.gz)

# user db - it's complicated
for f in group gshadow passwd shadow; do
    # now bind mount read-only those passwd files on boot
    cat >/etc/systemd/system/etc-"$f".mount <<EOF2
[Unit]
Description=Mount root/test-etc/$f over system etc/$f
Before=ssh.service

[Mount]
What=/root/test-etc/$f
Where=/etc/$f
Type=none
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF2
    systemctl enable etc-"$f".mount
    systemctl start etc-"$f".mount
done

#mkdir -p /home/test
#chown 12345:12345 /home/test
mkdir -p /home/ubuntu
chown 1000:1000 /home/ubuntu
mkdir -p /etc/sudoers.d/
#echo 'test ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/99-test-user
echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/99-ubuntu-user
sed -i 's/\#\?\(PermitRootLogin\|PasswordAuthentication\)\>.*/\1 yes/' /etc/ssh/sshd_config
echo "MaxAuthTries 120" >> /etc/ssh/sshd_config
grep '^PermitRootLogin yes' /etc/ssh/sshd_config
systemctl reload ssh

touch /root/spread-setup-done
EOF
    chmod 0755 "$UNPACK_DIR"/usr/lib/snapd/snapd.spread-tests-run-mode-tweaks.sh

    snap pack "$UNPACK_DIR" "$TARGET"
    rm -rf "$UNPACK_DIR"
}

setup_core_for_testing_by_modify_writable() {
    UNPACK_DIR="$1"

    # create test user and ubuntu user inside the writable partition
    # so that we can use a stock core in tests
    mkdir -p /mnt/user-data/test

    # create test user, see the comment in spread.yaml about 12345
    mkdir -p /mnt/system-data/etc/sudoers.d/
    echo 'test ALL=(ALL) NOPASSWD:ALL' >> /mnt/system-data/etc/sudoers.d/99-test-user
    echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /mnt/system-data/etc/sudoers.d/99-ubuntu-user
    # modify sshd so that we can connect as root
    mkdir -p /mnt/system-data/etc/ssh
    cp -a "$UNPACK_DIR"/etc/ssh/* /mnt/system-data/etc/ssh/
    # core18 is different here than core16
    sed -i 's/\#\?\(PermitRootLogin\|PasswordAuthentication\)\>.*/\1 yes/' /mnt/system-data/etc/ssh/sshd_config
    # ensure the setting is correct
    grep '^PermitRootLogin yes' /mnt/system-data/etc/ssh/sshd_config

    # build the user database - this is complicated because:
    # - spread on linode wants to login as "root"
    # - "root" login on the stock core snap is disabled
    # - uids between classic/core differ
    # - passwd,shadow on core are read-only
    # - we cannot add root to extrausers as system passwd is searched first
    # - we need to add our ubuntu and test users too
    # So we create the user db we need in /root/test-etc/*:
    # - take core passwd without "root"
    # - append root
    # - make sure the group matches
    # - bind mount /root/test-etc/* to /etc/* via custom systemd job
    # We also create /var/lib/extrausers/* and append ubuntu,test there
    test ! -e /mnt/system-data/root
    mkdir -m 700 /mnt/system-data/root
    test -d /mnt/system-data/root
    mkdir -p /mnt/system-data/root/test-etc
    mkdir -p /mnt/system-data/var/lib/extrausers/
    touch /mnt/system-data/var/lib/extrausers/sub{uid,gid}
    mkdir -p /mnt/system-data/etc/systemd/system/multi-user.target.wants
    for f in group gshadow passwd shadow; do
        # the passwd from core without root
        grep -v "^root:" "$UNPACK_DIR/etc/$f" > /mnt/system-data/root/test-etc/"$f"
        # append this systems root user so that linode can connect
        grep "^root:" /etc/"$f" >> /mnt/system-data/root/test-etc/"$f"

        # make sure the group is as expected
        chgrp --reference "$UNPACK_DIR/etc/$f" /mnt/system-data/root/test-etc/"$f"
        # now bind mount read-only those passwd files on boot
        cat >/mnt/system-data/etc/systemd/system/etc-"$f".mount <<EOF
[Unit]
Description=Mount root/test-etc/$f over system etc/$f
Before=ssh.service

[Mount]
What=/root/test-etc/$f
Where=/etc/$f
Type=none
Options=bind,ro

[Install]
WantedBy=multi-user.target
EOF
        ln -s /etc/systemd/system/etc-"$f".mount /mnt/system-data/etc/systemd/system/multi-user.target.wants/etc-"$f".mount

        # create /var/lib/extrausers/$f
        # append ubuntu, test user for the testing
        grep "^test:" /etc/$f >> /mnt/system-data/var/lib/extrausers/"$f"
        grep "^ubuntu:" /etc/$f >> /mnt/system-data/var/lib/extrausers/"$f"
        # check test was copied
        MATCH "^test:" </mnt/system-data/var/lib/extrausers/"$f"
        MATCH "^ubuntu:" </mnt/system-data/var/lib/extrausers/"$f"
    done

    # Make sure systemd-journal group has the "test" user as a member. Due to the way we copy that from the host
    # and merge it from the core snap this is done explicitly as a second step.
    sed -r -i -e 's/^systemd-journal:x:([0-9]+):$/systemd-journal:x:\1:test/' /mnt/system-data/root/test-etc/group

    # ensure spread -reuse works in the core image as well
    if [ -e /.spread.yaml ]; then
        cp -av /.spread.yaml /mnt/system-data
    fi

    # using symbolic names requires test:test have the same ids
    # inside and outside which is a pain (see 12345 above), but
    # using the ids directly is the wrong kind of fragile
    chown --verbose test:test /mnt/user-data/test

    # we do what sync-dirs is normally doing on boot, but because
    # we have subdirs/files in /etc/systemd/system (created below)
    # the writeable-path sync-boot won't work
    mkdir -p /mnt/system-data/etc/systemd

    mkdir -p /mnt/system-data/var/lib/console-conf

    # NOTE: The here-doc below must use tabs for proper operation.
    cat >/mnt/system-data/etc/systemd/system/var-lib-systemd-linger.mount <<-UNIT
	[Mount]
	What=/writable/system-data/var/lib/systemd/linger
	Where=/var/lib/systemd/linger
	Options=bind
	UNIT
    ln -s /etc/systemd/system/var-lib-systemd-linger.mount /mnt/system-data/etc/systemd/system/multi-user.target.wants/var-lib-systemd-linger.mount

    # NOTE: The here-doc below must use tabs for proper operation.
    mkdir -p /mnt/system-data/etc/systemd/system/systemd-logind.service.d
    cat >/mnt/system-data/etc/systemd/system/systemd-logind.service.d/linger.conf <<-CONF
	[Service]
	StateDirectory=systemd/linger
	CONF

    (cd /tmp ; unsquashfs -no-progress -v  /var/lib/snapd/snaps/"$core_name"_*.snap etc/systemd/system)
    cp -avr /tmp/squashfs-root/etc/systemd/system /mnt/system-data/etc/systemd/
}

setup_reflash_magic() {
    # install the stuff we need
    distro_install_package kpartx busybox-static

    distro_clean_package_cache

    # need to be seeded to proceed with snap install
    snap wait system seed.loaded

    # download the snapd snap for all uc systems except uc16
    if ! os.query is-core16; then
        snap download "--channel=${SNAPD_CHANNEL}" snapd
    fi

    # we cannot use "snaps.names tool" here because no snaps are installed yet
    core_name="core"
    if os.query is-core18; then
        core_name="core18"
    elif os.query is-core20; then
        core_name="core20"
    elif os.query is-core22; then
        core_name="core22"
    fi
    # XXX: we get "error: too early for operation, device not yet
    # seeded or device model not acknowledged" here sometimes. To
    # understand that better show some debug output.
    snap changes
    snap tasks --last=seed || true
    journalctl -u snapd
    snap model --verbose
    # remove the above debug lines once the mentioned bug is fixed
    snap install "--channel=${CORE_CHANNEL}" "$core_name"
    UNPACK_DIR="/tmp/$core_name-snap"
    unsquashfs -no-progress -d "$UNPACK_DIR" /var/lib/snapd/snaps/${core_name}_*.snap

    if os.query is-core16; then
        # the new ubuntu-image expects mkfs to support -d option, which was not
        # supported yet by the version of mkfs that shipped with Ubuntu 16.04
        snap install ubuntu-image --channel="$UBUNTU_IMAGE_SNAP_CHANNEL" --classic
    else
        # shellcheck source=tests/lib/image.sh
        . "$TESTSLIB/image.sh"
        get_ubuntu_image
    fi

    # needs to be under /home because ubuntu-device-flash
    # uses snap-confine and that will hide parts of the hostfs
    IMAGE_HOME=/home/image
    IMAGE=pc.img
    mkdir -p "$IMAGE_HOME"

    # ensure that ubuntu-image is using our test-build of snapd with the
    # test keys and not the bundled version of usr/bin/snap from the snap.
    # Note that we can not put it into /usr/bin as '/usr' is different
    # when the snap uses confinement.
    cp /usr/bin/snap "$IMAGE_HOME"
    export UBUNTU_IMAGE_SNAP_CMD="$IMAGE_HOME/snap"

    if os.query is-core18; then
        cp "$TESTSLIB/assertions/ubuntu-core-18-amd64.model" "$IMAGE_HOME/pc.model"
    elif os.query is-core20; then
        repack_snapd_snap_with_run_mode_firstboot_tweaks "$IMAGE_HOME"
        cp "$TESTSLIB/assertions/ubuntu-core-20-amd64.model" "$IMAGE_HOME/pc.model"
    elif os.query is-core22; then
        repack_snapd_snap_with_run_mode_firstboot_tweaks "$IMAGE_HOME"
        cp "$TESTSLIB/assertions/ubuntu-core-22-amd64.model" "$IMAGE_HOME/pc.model"
    else
        printf "ERROR: unsupported UC release\n"
        return 1
    fi

    EXTRA_FUNDAMENTAL=
    IMAGE_CHANNEL=edge
    if [ "$KERNEL_CHANNEL" = "$GADGET_CHANNEL" ]; then
        IMAGE_CHANNEL="$KERNEL_CHANNEL"
    else
        # download pc-kernel snap for the specified channel and set
        # ubuntu-image channel to that of the gadget, so that we don't
        # need to download it
        snap download --channel="$KERNEL_CHANNEL" pc-kernel

        EXTRA_FUNDAMENTAL="--snap $PWD/pc-kernel_*.snap"
        IMAGE_CHANNEL="$GADGET_CHANNEL"
    fi

    if os.query is-core20 || os.query is-core22; then
        if os.query is-core20; then
            BRANCH=20
        elif os.query is-core22; then
            BRANCH=22
        fi
        snap download --basename=pc-kernel --channel="${BRANCH}/${KERNEL_CHANNEL}" pc-kernel
        # make sure we have the snap
        test -e pc-kernel.snap
        mv "$PWD/pc-kernel.snap" "$IMAGE_HOME"
        EXTRA_FUNDAMENTAL="--snap $IMAGE_HOME/pc-kernel.snap"

        # also add debug command line parameters to the kernel command line via
        # the gadget in case things go side ways and we need to debug
        snap download --basename=pc --channel="${BRANCH}/${KERNEL_CHANNEL}" pc
        test -e pc.snap
        unsquashfs -d pc-gadget pc.snap

        # TODO: it would be desirable when we need to do in-depth debugging of
        # UC20 runs in google to have snapd.debug=1 always on the kernel command
        # line, but we can't do this universally because the logic for the env
        # variable SNAPD_DEBUG=0|false does not overwrite the turning on of
        # debug messages in some places when the kernel command line is set, so
        # we get failing tests since there is extra stuff on stderr than
        # expected in the test when SNAPD_DEBUG is turned off
        # so for now, don't include snapd.debug=1, but eventually it would be
        # nice to have this on

        if [ "$SPREAD_BACKEND" = "google" ]; then
            # the default console settings for snapd aren't super useful in GCE,
            # instead it's more useful to have all console go to ttyS0 which we
            # can read more easily than tty1 for example
            for cmd in "console=ttyS0" "dangerous" "systemd.journald.forward_to_console=1" "rd.systemd.journald.forward_to_console=1" "panic=-1"; do
                echo "$cmd" >> pc-gadget/cmdline.full
            done
        else
            # but for other backends, just add the additional debugging things
            # on top of whatever the gadget currently is configured to use
            for cmd in "dangerous" "systemd.journald.forward_to_console=1" "rd.systemd.journald.forward_to_console=1"; do
                echo "$cmd" >> pc-gadget/cmdline.extra
            done
        fi

        # TODO: this probably means it's time to move this helper out of
        # nested.sh to somewhere more general

        #shellcheck source=tests/lib/nested.sh
        . "$TESTSLIB/nested.sh"
        KEY_NAME=$(nested_get_snakeoil_key)

        SNAKEOIL_KEY="$PWD/$KEY_NAME.key"
        SNAKEOIL_CERT="$PWD/$KEY_NAME.pem"

        nested_secboot_sign_gadget pc-gadget "$SNAKEOIL_KEY" "$SNAKEOIL_CERT"
        snap pack --filename=pc-repacked.snap pc-gadget
        mv pc-repacked.snap $IMAGE_HOME/pc-repacked.snap
        EXTRA_FUNDAMENTAL="$EXTRA_FUNDAMENTAL --snap $IMAGE_HOME/pc-repacked.snap"
    fi

    # Add snapd snap
    extra_snap=("$IMAGE_HOME"/snapd_*.snap)
    EXTRA_FUNDAMENTAL="$EXTRA_FUNDAMENTAL --snap ${extra_snap[0]}"

    # 'snap pack' creates snaps 0644, and ubuntu-image just copies those in
    # maybe we should fix one or both of those, but for now this'll do
    chmod 0600 "$IMAGE_HOME"/*.snap

    # download the core20 snap manually from the specified channel for UC20
    if os.query is-core20 || os.query is-core22; then
        if os.query is-core20; then
            BASE=core20
        elif os.query is-core22; then
            BASE=core22
        fi
        snap download "${BASE}" --channel="$BASE_CHANNEL" --basename="${BASE}"

        # we want to download the specific channel referenced by $BASE_CHANNEL,
        # but if we just seed that revision and $BASE_CHANNEL != $IMAGE_CHANNEL,
        # then immediately on booting, snapd will refresh from the revision that
        # is seeded via $BASE_CHANNEL to the revision that is in $IMAGE_CHANNEL,
        # so to prevent that from happening (since that automatic refresh will
        # confuse spread and make tests fail in awkward, confusing ways), we
        # unpack the snap and re-pack it so that it is not asserted and thus
        # won't be automatically refreshed
        # note that this means that when $IMAGE_CHANNEL != $BASE_CHANNEL, we
        # will have unasserted snaps for all snaps on UC20 in GCE spread:
        # * snapd (to include tweaks to be able to access the image)
        # * pc-kernel (to avoid automatic refreshes)
        # * pc (to aid in debugging by modifying the kernel command line)
        # * coreXX (to avoid automatic refreshes)
        if [ "$IMAGE_CHANNEL" != "$BASE_CHANNEL" ]; then
            unsquashfs -d "${BASE}-snap" "${BASE}.snap"
            snap pack --filename="${BASE}-repacked.snap" "${BASE}-snap"
            rm -r "${BASE}-snap"
            mv "${BASE}-repacked.snap" "${IMAGE_HOME}/${BASE}.snap"
        else
            mv "${BASE}.snap" "${IMAGE_HOME}/${BASE}.snap"
        fi

        EXTRA_FUNDAMENTAL="$EXTRA_FUNDAMENTAL --snap ${IMAGE_HOME}/${BASE}.snap"
    fi
    local UBUNTU_IMAGE="$LOCAL_BIN"/ubuntu-image
    if os.query is-core16; then
        # ubuntu-image on 16.04 needs to be installed from a snap
        UBUNTU_IMAGE=/snap/bin/ubuntu-image
    fi
    # shellcheck disable=SC2086
    "$UBUNTU_IMAGE" snap \
                    -w "$IMAGE_HOME" "$IMAGE_HOME/pc.model" \
                    --channel "$IMAGE_CHANNEL" \
                    $EXTRA_FUNDAMENTAL \
                    --output-dir "$IMAGE_HOME"
    rm -f ./pc-kernel_*.{snap,assert} ./pc-kernel.{snap,assert} ./pc_*.{snap,assert} ./core{20,22}.{snap,assert}

    if os.query is-core20 || os.query is-core22; then
        # (ab)use ubuntu-seed
        LOOP_PARTITION=2
    else
        LOOP_PARTITION=3
    fi

    # mount fresh image and add all our SPREAD_PROJECT data
    kpartx -avs "$IMAGE_HOME/$IMAGE"
    # losetup --list --noheadings returns:
    # /dev/loop1   0 0  1  1 /var/lib/snapd/snaps/ohmygiraffe_3.snap                0     512
    # /dev/loop57  0 0  1  1 /var/lib/snapd/snaps/http_25.snap                      0     512
    # /dev/loop19  0 0  1  1 /var/lib/snapd/snaps/test-snapd-netplan-apply_75.snap  0     512
    devloop=$(losetup --list --noheadings | grep "$IMAGE_HOME/$IMAGE" | awk '{print $1}')
    dev=$(basename "$devloop")

    # resize the 2nd partition from that loop device to fix the size
    if ! (os.query is-core20 || os.query is-core22); then
        resize2fs -p "/dev/mapper/${dev}p${LOOP_PARTITION}"
    fi

    # mount it so we can use it now
    mount "/dev/mapper/${dev}p${LOOP_PARTITION}" /mnt

    # copy over everything from gopath to user-data, exclude:
    # - VCS files
    # - built debs
    # - golang archive files and built packages dir
    # - govendor .cache directory and the binary,
    if os.query is-core16 || os.query is-core18; then
        mkdir -p /mnt/user-data/
        # we need to include "core" here because -C option says to ignore 
        # files the way CVS(?!) does, so it ignores files named "core" which
        # are core dumps, but we have a test suite named "core", so including 
        # this here will ensure that portion of the git tree is included in the
        # image
        rsync -a -C \
          --exclude '*.a' \
          --exclude '*.deb' \
          --exclude /gopath/.cache/ \
          --exclude /gopath/bin/govendor \
          --exclude /gopath/pkg/ \
          --include core/ \
          /home/gopath /mnt/user-data/
    elif os.query is-core20 || os.query is-core22; then
        # prepare passwd for run-mode-overlay-data

        # use /etc/{group,passwd,shadow,gshadow} from the core20 snap, merged
        # with some bits from our current system - we don't want to use the
        # /etc/group from the current system as classic and core gids and uids
        # don't match, but we still need the same test/ubuntu/root user info
        # in core as we currently have in classic
        mkdir -p /root/test-etc
        mkdir -p /var/lib/extrausers
        touch /var/lib/extrausers/sub{uid,gid}
        for f in group gshadow passwd shadow; do
            grep -v "^root:" "$UNPACK_DIR/etc/$f" > /root/test-etc/"$f"
            grep "^root:" /etc/"$f" >> /root/test-etc/"$f"
            chgrp --reference "$UNPACK_DIR/etc/$f" /root/test-etc/"$f"
            # create /var/lib/extrausers/$f
            # append ubuntu, test user for the testing
            ##grep "^test:" /etc/"$f" >> /var/lib/extrausers/"$f"
            grep "^ubuntu:" /etc/"$f" >> /var/lib/extrausers/"$f"
            # check test was copied
            ##grep "^test:" </var/lib/extrausers/"$f"
            grep "^ubuntu:" </var/lib/extrausers/"$f"
        done
        # Make sure systemd-journal group has the "test" user as a member. Due
        # to the way we copy that from the host and merge it from the core snap
        # this is done explicitly as a second step.
        sed -r -i -e 's/^systemd-journal:x:([0-9]+):$/systemd-journal:x:\1:test/' /root/test-etc/group
        tar -c -z \
          --exclude '*.a' \
          --exclude '*.deb' \
          --exclude /gopath/.cache/ \
          --exclude /gopath/bin/govendor \
          --exclude /gopath/pkg/ \
          -f /mnt/run-mode-overlay-data.tar.gz \
          "$PROJECT_PATH" /root/test-etc /var/lib/extrausers
    fi

    # now modify the image writable partition - only possible on uc16 / uc18
    if os.query is-core16 || os.query is-core18; then
        # modify the writable partition of "core" so that we have the
        # test user
        setup_core_for_testing_by_modify_writable "$UNPACK_DIR"
    fi

    # unmount the partition we just modified and delete the image's loop devices
    umount /mnt
    kpartx -d "$IMAGE_HOME/$IMAGE"

    # the reflash magic
    # FIXME: ideally in initrd, but this is good enough for now
    cat > "$IMAGE_HOME/reflash.sh" << EOF
#!/tmp/busybox sh
set -e
set -x

# blow away everything
OF=/dev/sda
if [ -e /dev/vda ]; then
    OF=/dev/vda
fi
dd if=/tmp/$IMAGE of=\$OF bs=4M
# and reboot
sync
echo b > /proc/sysrq-trigger

EOF

    cat > "$IMAGE_HOME/prep-reflash.sh" << EOF
#!/bin/sh -ex
mount -t tmpfs none /tmp
cp /bin/busybox /tmp
cp $IMAGE_HOME/reflash.sh /tmp
cp $IMAGE_HOME/$IMAGE /tmp
sync

# re-exec using busybox from /tmp
exec /tmp/reflash.sh

EOF
    chmod +x "$IMAGE_HOME/reflash.sh"
    chmod +x "$IMAGE_HOME/prep-reflash.sh"

    DEVPREFIX=""
    if os.query is-core20 || os.query is-core22; then
        DEVPREFIX="/boot"
    fi
    # extract ROOT from /proc/cmdline
    ROOT=$(sed -e 's/^.*root=//' -e 's/ .*$//' /proc/cmdline)
    cat >/boot/grub/grub.cfg <<EOF
set default=0
set timeout=2
menuentry 'flash-all-snaps' {
linux $DEVPREFIX/vmlinuz root=$ROOT ro init=$IMAGE_HOME/prep-reflash.sh console=tty1 console=ttyS0
initrd $DEVPREFIX/initrd.img
}
EOF
}

# prepare_ubuntu_core will prepare ubuntu-core 16+
prepare_ubuntu_core() {
    # we are still a "classic" image, prepare the surgery
    if [ -e /var/lib/dpkg/status ]; then
        setup_reflash_magic
        REBOOT
    fi

    disable_journald_rate_limiting
    disable_journald_start_limiting

    # verify after the first reboot that we are now in UC world
    if [ "$SPREAD_REBOOT" = 1 ]; then
        echo "Ensure we are now in an all-snap world"
        if [ -e /var/lib/dpkg/status ]; then
            echo "Rebooting into all-snap system did not work"
            exit 1
        fi
    fi

    # Wait for the snap command to become available.
    if [ "$SPREAD_BACKEND" != "external" ]; then
        # shellcheck disable=SC2016
        retry -n 120 --wait 1 sh -c 'test "$(command -v snap)" = /usr/bin/snap'
    fi

    # Wait for seeding to finish.
    snap wait system seed.loaded

    echo "Ensure fundamental snaps are still present"
    for name in "$(snaps.name gadget)" "$(snaps.name kernel)" "$(snaps.name core)"; do
        if ! snap list "$name"; then
            echo "Not all fundamental snaps are available, all-snap image not valid"
            echo "Currently installed snaps"
            snap list
            exit 1
        fi
    done

    echo "Ensure the snapd snap is available"
    if os.query is-core18 || os.query is-core20 || os.query is-core22; then
        if ! snap list snapd; then
            echo "snapd snap on UC18+ is missing"
            snap list
            exit 1
        fi
    fi

    echo "Ensure rsync is available"
    if ! command -v rsync; then
        rsync_snap="test-snapd-rsync"
        if os.query is-core18; then
            rsync_snap="test-snapd-rsync-core18"
        elif os.query is-core20; then
            rsync_snap="test-snapd-rsync-core20"
        elif os.query is-core22; then
            rsync_snap="test-snapd-rsync-core22"
        fi
        snap install --devmode --edge "$rsync_snap"
        snap alias "$rsync_snap".rsync rsync
    fi

    # Cache snaps
    # shellcheck disable=SC2086
    cache_snaps ${PRE_CACHE_SNAPS}

    echo "Ensure the core snap is cached"
    # Cache snaps
    if os.query is-core18 || os.query is-core20 || os.query is-core22; then
        if snap list core >& /dev/null; then
            echo "core snap on UC18+ should not be installed yet"
            snap list
            exit 1
        fi
        cache_snaps core
        if os.query is-core18; then
            cache_snaps test-snapd-sh-core18
        fi
        if os.query is-core20; then
            cache_snaps test-snapd-sh-core20
        fi
        if os.query is-core22; then
            cache_snaps test-snapd-sh-core22
        fi
    fi

    disable_refreshes
    disable_kernel_rate_limiting
}

cache_snaps(){
    # Pre-cache snaps so that they can be installed by tests quickly.
    # This relies on a behavior of snapd which snaps installed are
    # cached and then used when need to the installed again

    # Download each of the snaps we want to pre-cache. Note that `snap download`
    # a quick no-op if the file is complete.
    for snap_name in "$@"; do
        snap download "$snap_name"

        # Copy all of the snaps back to the spool directory. From there we
        # will reuse them during subsequent `snap install` operations.
        snap_file=$(ls "${snap_name}"_*.snap)
        mv "${snap_file}" /var/lib/snapd/snaps/"${snap_file}".partial
        rm -f "${snap_name}"_*.assert
    done
}
