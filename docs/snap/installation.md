---
title: "Install NetworkManager"
table_of_contents: True
---

# Install NetworkManager

The NetworkManager snap is currently available from the Ubuntu Store. It can
be installed on any system that supports snaps but is only recommended on
[Ubuntu Core](https://www.ubuntu.com/core) at the moment.

You can install the snap with the following command:

```
 $ snap install network-manager
 network-manager 1.2.2-10 from 'canonical' installed
```

Although the network-manager snap is available from other channels (candidate, beta, edge),
only the stable version should be used for production devices. Their meaning is internal
to the development team of the network-manager snap.

All necessary plugs and slots will be automatically connected within the
installation process. You can verify this with:

```
$ snap interfaces network-manager
Slot                     Plug
:network-setup-observe   network-manager
:ppp                     network-manager
network-manager:service  network-manager:nmcli
-                        network-manager:modem-manager
```

**NOTE:** The _network-manager:modem-manager_ plug only gets connected when the
_modem-manager_ snap is installed too. Otherwise it stays disconnected.

Once the installation has successfully finished the
NetworkManager service is running in the background. You can check its current
status with

```
 $ systemctl status snap.networkmanager
 ● snap.networkmanager.service - Service for snap application networkmanager
   Loaded: loaded (/etc/systemd/system/snap.networkmanager.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2017-02-16 09:59:39 UTC; 16s ago
   Main PID: 1389 (networkmanager)
   [...]
```

Now you have NetworkManager successfully installed.

## Next Steps

 * [Enable Ethernet Support](enable-ethernet-support.md)
 * [Explore Network Status](explore-network-status.md)
 * [Configure WiFi Connections](configure-wifi-connections.md)
 * [Configure Cellular Connections](configure-cellular-connections.md)
 * [Edit Network Connections](edit-connections.md)
 * [Routing Tables](routing-tables.md)
 * [Logging Messages](logging-messages.md)
 * [Enable Debug Support](reference/snap-configuration/debug.md)
