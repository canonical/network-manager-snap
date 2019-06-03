---
title: "FAQ"
table_of_contents: False
---

# FAQ

This section covers some of the most commonly encountered problems and attempts
to provide solutions for them.

## Ethernet devices are not used

### Possible cause: Ethernet support is disabled for NetworkManager

By default the network-manager snap disables Ethernet support to avoid conflicts
with networkd/netplan which are used by default on Ubuntu Core 16. See
*[Enable Ethernet Support](enable-ethernet-support.md)* for details on how to
enable it.
