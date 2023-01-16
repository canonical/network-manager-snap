#!/bin/bash -ex
# shellcheck source=tests/lib/utilities.sh
. "$SYSTEMSNAPSTESTLIB"/utilities.sh

# Cleanup logs so we can just dump what has happened in the debug-each
# step below after a test case ran.
journalctl --rotate
journalctl --vacuum-time=1ms
dmesg -c > /dev/null

echo "Wait for firstboot change to be ready"
while ! snap changes | grep -q "Done"; do
    snap changes || true
    snap change 1 || true
    sleep 1
done

echo "Ensure fundamental snaps are still present"
# shellcheck source=tests/lib/snap-names.sh
. "$SYSTEMSNAPSTESTLIB"/snap-names.sh
for name in "$gadget_name" "$kernel_name" "$core_name"; do
    if ! snap list | grep -q "$name" ; then
	echo "Not all fundamental snaps are available, all-snap image not valid"
	echo "Currently installed snaps:"
	snap list
	exit 1
    fi
done

snap_install network-manager --channel=22/stable
wait_for_network_manager

# For debugging dump all snaps and connected slots/plugs
snap list
snap connections --all
