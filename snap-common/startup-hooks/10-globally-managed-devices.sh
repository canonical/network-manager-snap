#!/bin/sh

# Prior to 1.42 network-manager did not manage the loopback device, as it
# was treated as a special device. By default we want to manage all network
# devices on the machine, but let us leave the loopback device unmanaged
# completely to preserve the previous behavior. Leaving default settings for
# the loopback device has been observed to cause loss of connection when 
# removing/installing. 
# After a reinstall the loopback device is then only added but the connection 
# is then not brought back up.
#
# Creating this file specifically causes the default of managing all devices
# (which seems in line with docs) with the exception of the loopback device.
if [ ! -e "$SNAP_DATA"/conf.d/10-globally-managed-devices.conf ] ; then
	mkdir -p "$SNAP_DATA"/conf.d
	cat <<-EOF > "$SNAP_DATA"/conf.d/10-globally-managed-devices.conf
		[keyfile]
		unmanaged-devices=interface-name:lo
	EOF
fi
