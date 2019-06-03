---
title: "Edit Connections"
table_of_contents: True
---

# Edit Connections

This part will show you how to use a network-manager built-in editor to modify
the connections as well as provide a reference for setting some of the
settings.

## Using nmcli Console

Aside from offering the possibility to manage and modify the network connections
using the command-line, network-manager offers a built-in, interactive
console to achieve the same. In order to use it type:

```
$ nmcli connection edit
```

It will bring up an interactive console. In the first step you will be prompted
to enter the connection type. The list of valid connection types will be
displayed on the screen. Once you select one you will be taken to the nmcli
console where you have the possibility to modify its parameters.

Alternatively, if you know the valid connection types, you could jump straight
to the nmcli console by providing the type as a parameter:

```
$ nmcli connection edit type <type>
```

where &lt;type&gt;  must be a valid connection type such as 'wifi'.

An attempt to edit the wifi connection type would look like:

```
$ nmcli c edit

Valid connection types: generic, 802-3-ethernet (ethernet), pppoe,
802-11-wireless (wifi), wimax, gsm, cdma, infiniband, adsl, bluetooth, vpn,
802-11-olpc-mesh (olpc-mesh), vlan, bond, team, bridge, bond-slave, team-slave,
bridge-slave, no-slave, tun, ip-tunnel, macvlan, vxlan
Enter connection type: wifi

===| nmcli interactive connection editor |===

Adding a new '802-11-wireless' connection

Type 'help' or '?' for available commands.
Type 'describe [<setting>.<prop>]' for detailed property description.

You may edit the following settings: connection, 802-11-wireless (wifi),
802-11-wireless-security (wifi-sec), 802-1x, ipv4, ipv6
nmcli>
```

From now on it is possible to edit the wifi connection settings. The list of
settings is provided as in the example above. The nmcli console offers a set of
commands that can be used to navigate between settings. To get the list of
available commands type 'help' or '?'

```
nmcli> ?
------------------------------------------------------------------------------
---[ Main menu ]---
goto     [<setting> | <prop>]        :: go to a setting or property
remove   <setting>[.<prop>] | <prop> :: remove setting or reset property value
set      [<setting>.<prop> <value>]  :: set property value
describe [<setting>.<prop>]          :: describe property
print    [all | <setting>[.<prop>]]  :: print the connection
verify   [all | fix]                 :: verify the connection
save     [persistent|temporary]      :: save the connection
activate [<ifname>] [/<ap>|<nsp>]    :: activate the connection
back                                 :: go one level up (back)
help/?   [<command>]                 :: print this help
nmcli    <conf-option> <value>       :: nmcli configuration
quit                                 :: exit nmcli
------------------------------------------------------------------------------
nmcli> 
```

## Change Connection Details

This section will show how to change some of the connection details including
IPv4 and IPv6 settings.

It is important to understand that every option can be modified using either the
command-line or the editor. The advantage of the editor is that it shows which
options are availabe for modification in contrast to the command-line which does
not.

It is possible however to learn about the available settings from the
command-line by printing the connection details. Type:

```
$ nmcli c show <name>
```

where &lt;name&gt; is the connection name.

The above will bring a fairly long list of text on the terminal, therefore it is
best to either use a pager or grep to make the results manageable.

### IPv4 and IPv6 Options

For example for IPv4 settings one would do:

```
$ nmcli c show <name> | grep ipv4
ipv4.method:                            auto
ipv4.dns:
ipv4.dns-search:
ipv4.dns-options:                       (default)
ipv4.addresses:
ipv4.gateway:                           --
ipv4.routes:
ipv4.route-metric:                      -1
ipv4.ignore-auto-routes:                no
ipv4.ignore-auto-dns:                   no
ipv4.dhcp-client-id:                    --
ipv4.dhcp-timeout:                      0
ipv4.dhcp-send-hostname:                yes
ipv4.dhcp-hostname:                     --
ipv4.dhcp-fqdn:                         --
ipv4.never-default:                     no
ipv4.may-fail:                          yes
ipv4.dad-timeout:                       -1 (default)
```

For example setting up the DNS server would require typing:

```
$ nmcli c modify <name> ipv4.dns "8.8.8.8"
```

The rest of the settings can be modified in the same fashion.

### WiFi Powersave Option

The WiFi powersave option can have one of the following values:

| Value | Meaning                                           |
|-------|---------------------------------------------------|
| 0     | Default                                           |
| 1     | Ignore, do not touch currently configured setting |
| 2     | Disable                                           |
| 3     | Enable                                            |

Changing it is as simple as:

```
$ nmcli c modify <name> 802-11-wireless.powersave 2
```
