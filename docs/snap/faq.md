---
title: "FAQ"
table_of_contents: False
---

# FAQ

This section covers some of the most commonly encountered problems and attempts
to provide solutions for them.

## Ethernet devices are not used

### Possible cause: Ethernet support is disabled for NetworkManager

The core16 based network-manager snap (1.2.2 version) disables by default
ethernet support to avoid conflicts
with networkd/netplan. See
*[NetworkManager and netplan](networkmanager-and-netplan.md)* for details on how to
enable it.
