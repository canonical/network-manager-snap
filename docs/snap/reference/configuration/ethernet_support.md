---
title: Ethernet Support
table_of_contents: true
---

# Ethernet Support

*Available since:* 1.2.2-12

The NetworkManager snap provides a configuration option to adjust
if it should manage ethernet network connections.

By default the NetworkManager snap **does not** manage ethernet network
devices as it would conflict with the default network management in
Ubuntu Core which is handled by [netplan](https://launchpad.net/netplan) and
[networkd](https://www.freedesktop.org/software/systemd/man/systemd-networkd.service.html).

## Enable Ethernet Support

To enable management of ethernet network devices the snap provides the
*ethernet.enable* configuration option.

This configuration option accepts the following values

 * **false (default):** Ethernet support is disabled. All network
 devices matching the expression 'en*' or 'eth*' will be ignored.
 * **true:** All ethernet devices available on the system will be
 managed by NetworkManager. networkd will not manage any of these
 anymore.

Changing the *ethernet* configuration option needs a reboot of the
device it's running on.

After the device has rebooted ethernet support is enabled NetworkManager will
take over management of all available ethernet network devices on the device.

NetworkManager will reuse existing configurations files from */etc/netplan*
when ethernet support is enabled. Those will marked as immutable inside
NetworkManager and any changes need to be written manually into the relevant
files in */etc/netplan*.

Example:

```
 $ snap set network-manager ethernet.enable=true
 $ sudo reboot
```
