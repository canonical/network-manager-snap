#!/bin/bash

. $TESTSLIB/snap-names.sh
. $TESTSLIB/utilities.sh

# Remove all snaps not being the core, gadget, kernel or snap we're testing
for snap in /snap/*; do
	snap="${snap:6}"
	case "$snap" in
		"bin" | "$gadget_name" | "$kernel_name" | core* | "$SNAP_NAME" )
			;;
		*)
			snap remove "$snap"
			;;
	esac
done

# Drop any generated or modified netplan configuration files. The original
# ones will be restored below.
rm -f /etc/netplan/*

# Ensure we have the same state for snapd as we had before
systemctl stop snapd.service snapd.socket
rm -rf /var/lib/snapd/*
tar xzf $SPREAD_PATH/snapd-state.tar.gz -C /
rm -rf /root/.snap
systemctl start snapd.service snapd.socket
wait_for_systemd_service snapd.service
wait_for_systemd_service snapd.socket

# Make sure the original netplan configuration is applied and active
# (we do this before re-starting NM to avoid race conditions in some tests)
netplan generate
netplan apply

systemctl stop snap.network-manager.networkmanager
rm -rf /var/snap/network-manager/*
tar xzf $SPREAD_PATH/nm-state.tar.gz -C /
systemctl start snap.network-manager.networkmanager
wait_for_network_manager
