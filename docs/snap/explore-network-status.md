---
title: "Explore Network Status"
table_of_contents: False
---

# Exploring Network Status

This section shows how to use the nmcli command-line tool to examine the status
of NetworkManager’s connections and devices.

Show the status of devices known to NetworkManager:

```
$ nmcli d
```

Show more information for this option:

```
$ nmcli d --help
```

Show the current status of each of NetworkManager’s connections:

```
$ nmcli c
```

Command “c” is for connections but is a abbreviated form of the real command
"connections". As for the devices command, “--help” shows more information for
this option. Finally, we can see the state of radio interfaces, including WiFi
and WWAN (cellular) with:

```
$ nmcli r
WIFI-HW  WIFI     WWAN-HW  WWAN    
enabled  enabled  enabled  enabled
```

It is important to make sure that WiFi/WWAN radios are enabled so the respective
connection types can establish a connection (we will specify how to this in
following sections). As with the other commands, “--help” shows usage information.

Observe NetworkManage activity (changes in connectivity state, devices or
connection properties):

```
$ nmcli monitor
```

See nmcli connection monitor and nmcli device monitor to watch for changes in
certain connections or devices.
