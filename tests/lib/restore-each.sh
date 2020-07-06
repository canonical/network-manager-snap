#!/bin/bash

# shellcheck source=tests/lib/snap-names.sh
. "$TESTSLIB"/snap-names.sh
# shellcheck source=tests/lib/utilities.sh
. "$TESTSLIB"/utilities.sh

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
systemctl stop snap.network-manager.networkmanager
rm -rf /var/snap/network-manager/*
tar xzf "$SPREAD_PATH"/nm-state.tar.gz -C /
# Wait a bit to avoid hitting re-start limit
sleep 2

# Make sure the original netplan configuration is applied and active
# (we do this before re-starting NM to avoid race conditions in some tests)
netplan apply

systemctl start snap.network-manager.networkmanager
wait_for_network_manager
