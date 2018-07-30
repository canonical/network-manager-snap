#!/bin/sh

# Enable wake-on-lan by default until we have a configuration
# hook to do that.
if [ ! -e $SNAP_DATA/conf.d/enable-wol.conf ] ; then
	mkdir -p $SNAP_DATA/conf.d
	cat <<-EOF > $SNAP_DATA/conf.d/enable-wol.conf
		[connection]
		# Value 64 maps to the 'magic' setting; see man nm-settings
		# for more information.
		802-3-ethernet.wake-on-lan=64
	EOF
fi
