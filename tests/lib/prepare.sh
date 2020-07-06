#!/bin/bash
# shellcheck source=tests/lib/utilities.sh
. "$TESTSLIB"/utilities.sh

echo "Wait for firstboot change to be ready"
while ! snap changes | grep -q "Done"; do
	snap changes || true
	snap change 1 || true
	sleep 1
done

echo "Ensure fundamental snaps are still present"
# shellcheck source=tests/lib/snap-names.sh
. "$TESTSLIB"/snap-names.sh
for name in "$gadget_name" "$kernel_name" "$core_name"; do
	if ! snap list | grep -q "$name" ; then
		echo "Not all fundamental snaps are available, all-snap image not valid"
		echo "Currently installed snaps:"
		snap list
		exit 1
	fi
done

# Remove any existing state archive from other test suites
rm -f /home/network-manager/nm-state.tar.gz

# TODO install from stable once NM core20 is released there
snap_install network-manager --channel=20/beta

# snapshot NetworkManager's state
sleep 2
systemctl stop snap.network-manager.networkmanager
tar czf "$SPREAD_PATH"/nm-state.tar.gz /var/snap/network-manager /etc/netplan
# Wait a bit to avoid hitting re-start limit
sleep 2
# Make sure the original netplan configuration is applied and active
# (we do this before re-starting NM to avoid race conditions in some tests)
netplan apply
systemctl start snap.network-manager.networkmanager
wait_for_network_manager

# For debugging dump all snaps and connected slots/plugs
snap list
snap connections --all
