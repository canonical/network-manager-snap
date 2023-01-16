#!/bin/bash -ex
# shellcheck source=tests/lib/utilities.sh
. "$SYSTEMSNAPSTESTLIB"/utilities.sh

# The first argument is the name of the snap under test
snap_name=$1

# Cleanup logs so we can just dump what has happened in the debug-each
# step below after a test case ran.
journalctl --rotate
journalctl --vacuum-time=1ms
dmesg -c > /dev/null

printf "Wait for firstboot change to be ready\n"
snap wait system seed.loaded

snap_install_from_file "$snap_name" 22/stable

# Wait for services shipped in the snap
# ("leftover" variable needed so we get the first column only in "service")
# shellcheck disable=SC2034
while read -r service leftover
do wait_for_systemd_service snap."$service"
done < <(snap services "$snap_name" | tail -n +2)

# For debugging dump all snaps and connected slots/plugs
snap list
snap connections --all
