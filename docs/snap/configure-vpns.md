---
title: "Configure a VPN"
table_of_contents: True
---

# Configure a VPN

The network-manager snap currently supports two types of VPN: OpenVPN and Wireguard.

## Configuring an OpenVPN connection

There are two ways in which you can create an OpenVPN connection with
network-manager, by importing a file with credentials or by setting
all needed parameters with nmcli invocations. In both cases, files
used in the definition must be copied to folders where the
network-manager snap has access, which is usually in SNAP_DATA or
SNAP_COMMON folders.

Using the first method we just need an OpenVPN configuration file:

    sudo nmcli c import type openvpn file /var/snap/network-manager/common/myopenvp.ovpn

It is important to run the previous command as root because it creates
some certificate and key files with data extracted from the
configuration file that need to be accessible by the network-manager
snap, which runs with root id.

Using the second method requires copying around certificates and keys
and creating/modifying the connection as required. For instance:

```
nmcli c add connection.id vpntest connection.type vpn \
    vpn.service-type org.freedesktop.NetworkManager.openvpn \
    ipv4.never-default true \
    ipv6.never-default true \
    +vpn.data ca=/var/snap/network-manager/common/creds/server_ca.crt \
    +vpn.data cert=/var/snap/network-manager/common/creds/user.crt \
    +vpn.data cert-pass-flags=0 \
    +vpn.data cipher=AES-128-CBC \
    +vpn.data comp-lzo=adaptive \
    +vpn.data connection-type=tls \
    +vpn.data dev=tun \
    +vpn.data key=/var/snap/network-manager/common/creds/user.key \
    +vpn.data ping=10 \
    +vpn.data ping-restart=60 \
    +vpn.data remote=<server>:<port> \
    +vpn.data remote-cert-tls=server \
    +vpn.data ta=/var/snap/network-manager/common/creds/tls_auth.key \
    +vpn.data ta-dir=1 \
    +vpn.data verify-x509-name=name:access.is
```

## Configuring a Wireguard connection

The recommended way to configure a connection is by placing a
wireguard configuration file in a folder that is readable by the
network-manager snap, and import with the following:

    nmcli c import type wireguard file /var/snap/nm-vpn-client/common/wg.conf

It is possible to create the connection by using `nmcli` with multiple
parameters as well, but unfortunately configuring peers is not
possible at the moment [1].

## Configuring a VPN programmatically

To create a VPN connection programmatically, that is, from another
snap, the user snap must define a content interface with a slot that
needs to connect to the `vpn-creds` plug that is defined in the
network-manager snap. Once connected, the user can drop in that folder
any file necessary to create the connection. That folder is seen by NM
as `/var/snap/network-manager/common/creds`, so all file paths need to
have that prefix. After that, a connection can be created by using
NM's dbus interface (a connected network-manager plug is required).

[1] https://blogs.gnome.org/thaller/2019/03/15/wireguard-in-networkmanager/
