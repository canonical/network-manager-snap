---
title: "Release Notes"
table_of_contents: False
---

# Release Notes

The version numbers mentioned on this page correspond to those released in the
Ubuntu snap store.

You can check with the following command which version you have currently
installed:

```
$ snap info network-manager
name:      network-manager
summary:   "Network management based on NeworkManager"
publisher: canonical
description: |
  Network management of wired Ethernet, WiFi and mobile data connection based on
  NetworkManager and ModemManager
commands:
  - nmcli
tracking:    stable
installed:   1.2.2-10 (73) 5MB -
[...]
```
</br>
## 1.2.2-11

 * Wake-on-WLAN can be configured via snap/nmcli
 * Automatic reconfiguration of network devices when device comes back from a
   low power state
 * Snap alias available for nmcli
 * WiFi powersave is configurable via snap configuration
