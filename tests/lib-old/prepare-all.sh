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
