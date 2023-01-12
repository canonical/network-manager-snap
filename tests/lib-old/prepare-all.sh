#!/bin/bash -x

# Create a service to get the mac80211_hwsim driver loaded on system
# startup so that we don't need to load it again in our tests as
# load/unload multiple times in a running system can lead to kernel
# crashes.
cat << EOF > /etc/systemd/system/load-mac80211-hwsim.service
[Unit]
Description=Load mac8022_hwsim driver
[Service]
ExecStart=/sbin/modprobe mac80211_hwsim radios=2
[Install]
WantedBy=multi-user.target
EOF

systemctl enable load-mac80211-hwsim
systemctl start load-mac80211-hwsim

# We don't have to build a snap when we should use one from a
# channel
if [ -n "$SNAP_CHANNEL" ] ; then
	exit 0
fi

# If there is a network-manager snap prebuilt for us, lets take
# that one to speed things up.
if [ -f /writable/system-data/network-manager_*_amd64.snap ]; then
    mv /writable/system-data/network-manager_*_amd64.snap /home/network-manager/
fi
if [ -f /home/network-manager/network-manager_*_amd64.snap ] ; then
	exit 0
fi

printf "No snap for installation found\n"
exit 1
