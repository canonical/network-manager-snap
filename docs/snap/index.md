---
title: "NetworkManager"
table_of_contents: False
---

# About NetworkManager

NetworkManager is a system network service that manages your network
devices and connections and attempts to keep network connectivity active
when available. It manages Ethernet, WiFi, mobile broadband (WWAN) and
PPPoE devices while also providing VPN integration with a variety of
different VPN services.

By default network management on [Ubuntu
Core](https://www.ubuntu.com/core) is handled by systemd's
[networkd](https://www.freedesktop.org/software/systemd/man/systemd-networkd.service.html)
and [netplan](https://launchpad.net/netplan). However, when
NetworkManager is installed, it will take control of all networking
devices in the system by creating a netplan configuration file in which
it sets itself as the default network renderer.

## What NetworkManager Offers

The upstream NetworkManager project offers a wide range of features and
most, but not all of them, are available in the snap package at the
moment.

Currently we provide support for the following high level features:

 * WiFi connectivity
 * WWAN connectivity (together with ModemManager)
 * Ethernet connectivity
 * WiFi access point creation
 * Shared connections

 Currently we do not support the following features:

  * VPN

## Upstream documentation

Existing documentation from the upstream project can be found
[here](https://wiki.gnome.org/Projects/NetworkManager).
