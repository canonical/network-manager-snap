#!/bin/bash -ex

# shellcheck source=tests/lib/snap-names.sh
. "$TESTSLIB"/snap-names.sh
# shellcheck source=tests/lib/utilities.sh
. "$TESTSLIB"/utilities.sh
get_qemu_eth_iface eth_if

# Remove all snaps not being the core, gadget, kernel or snap we're testing
for snap in /snap/*; do
	snap="${snap:6}"
	case "$snap" in
		README | bin | "$gadget_name" | "$kernel_name" | core* | snapd | "$SNAP_NAME")
			;;
		*)
			snap remove "$snap"
			;;
	esac
done

# Drop any generated or modified netplan configuration files. The original
# ones will be restored below.
rm -f /etc/netplan/*

sleep 2
# Make sure stopping the service does not fail as maybe we
# have removed the snap in the test.
systemctl stop snap.network-manager.networkmanager || true
rm -rf /var/snap/network-manager/*
tar xzf "$SPREAD_PATH"/nm-state.tar.gz -C /
# Wait a bit to avoid hitting re-start limit
sleep 2

snap_install network-manager --channel=20/stable

sleep 2

# Make sure the original netplan configuration is applied and active
# (we do this before re-starting NM to avoid race conditions in some tests)
netplan apply
# Remove ipv6 addresses (see LP:#1870561)
ip -6 address flush dev "$eth_if"

systemctl start snap.network-manager.networkmanager
wait_for_network_manager
