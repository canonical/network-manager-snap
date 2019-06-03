#!/bin/bash
. $TESTSLIB/utilities.sh

echo "Wait for firstboot change to be ready"
while ! snap changes | grep -q "Done"; do
	snap changes || true
	snap change 1 || true
	sleep 1
done

echo "Ensure fundamental snaps are still present"
. $TESTSLIB/snap-names.sh
for name in $gadget_name $kernel_name $core_name; do
	if ! snap list | grep -q $name ; then
		echo "Not all fundamental snaps are available, all-snap image not valid"
		echo "Currently installed snaps:"
		snap list
		exit 1
	fi
done

# Remove any existing state archive from other test suites
rm -f /home/network-manager/snapd-state.tar.gz
rm -f /home/network-manager/nm-state.tar.gz

# TODO install from stable once NM 1.10 is released there
snap_install network-manager --channel=1.10/beta

# Snapshot of the current snapd state for a later restore
systemctl stop snapd.service snapd.socket
tar czf $SPREAD_PATH/snapd-state.tar.gz /var/lib/snapd /etc/netplan
systemctl start snapd.socket

# Make sure the original netplan configuration is applied and active
# (we do this before re-starting NM to avoid race conditions in some tests)
netplan generate
netplan apply

# And also snapshot NetworkManager's state
systemctl stop snap.network-manager.networkmanager
tar czf $SPREAD_PATH/nm-state.tar.gz /var/snap/network-manager
systemctl start snap.network-manager.networkmanager

# For debugging dump all snaps and connected slots/plugs
snap list
snap interfaces
