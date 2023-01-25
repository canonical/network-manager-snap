#!/bin/bash -ex

# shellcheck source=cicd/lib/utilities.sh
. "$SYSTEMSNAPSTESTLIB"/utilities.sh

get_qemu_eth_iface eth_if
get_snap_names gadget_name kernel_name

do_network_reset=false
if snap list network-manager &> /dev/null
then do_network_reset=true
fi

# Remove all snaps not being snapd, core*, gadget, or kernel
for snap in /snap/*; do
    snap="${snap:6}"
    # shellcheck disable=SC2154
    case "$snap" in
	README | bin | "$gadget_name" | "$kernel_name" | core* | snapd)
	    ;;
	*)
	    snap remove --purge "$snap"
	    ;;
    esac
done

# Reset networking state if the NM snap was present
if [ "$do_network_reset" = "true" ]; then
    # Generate the default netplan configuration if no NM
    rm -f /etc/netplan/*
    # shellcheck disable=SC2154
    cat > /etc/netplan/"$DEFAULT_NETPLAN_FILE" <<EOF
network:
  ethernets:
    $eth_if:
      dhcp4: true
  version: 2
EOF

    # First generate to avoid netplan trying to restart NM while it does
    # not exist anymore.
    netplan generate
    netplan apply
fi
