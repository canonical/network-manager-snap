---
title: "Enable Ethernet Support"
table_of_contents: False
---

# Enable Ethernet Support

The default netplan configuration files in Ubuntu Core leave management of
Ethernet devices to networkd. Therefore, to avoid conflicts, the
network-manager snap does not manage Ethernet devices by default. The user has
to take care to enable it after installation if desired.

## Configure System for Ethernet Support

Before following the instructions below, backup the contents of /etc/netplan to
be able to restore it at a later point.

Also, note that this change might lead to a system without properly configured
network connections, which would lead to problems accessing the device, so be
careful when doing this.

To enable ethernet support, you have to set the `ethernet.enable` property to
`true`.  See how to do this [here](reference/configuration/ethernet_support.md).
When this is done, configuration files for netplan are created so
network-manager is the default netplan renderer. When set to `false` (the
default), the NM snap explicitly disables the management of ethernet devices to
avoid conflicts with networkd.

Rebooting the system will be needed for the changes to take effect.

After the reboot, NetworkManager should automatically set up attached Ethernet
ports or use existing netplan configuration files to setup connections.

Once logged into the system you may check the current connection status by

```
$ nmcli c show
```
