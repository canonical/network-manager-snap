#!/bin/bash -ex
# shellcheck source=tests/lib/utilities.sh
. "$SYSTEMSNAPSTESTLIB"/utilities.sh

# Cleanup logs so we can just dump what has happened in the debug-each
# step below after a test case ran.
journalctl --rotate
journalctl --vacuum-time=1ms
dmesg -c > /dev/null

printf "Wait for firstboot change to be ready\n"
snap wait system seed.loaded

printf "Ensure fundamental snaps are still presen\n"
# shellcheck source=tests/lib/snap-names.sh
. "$SYSTEMSNAPSTESTLIB"/snap-names.sh
for name in "$gadget_name" "$kernel_name" "$core_name"; do
    if ! snap list "$name" &> /dev/null; then
	printf "Not all fundamental snaps are available, UC image not valid\n"
	printf "Currently installed snaps:\n"
	snap list
	exit 1
    fi
done

snap_install_from_file network-manager 22/stable
wait_for_network_manager

# For debugging dump all snaps and connected slots/plugs
snap list
snap connections --all
