---
title: "Report a Bug"
table_of_contents: False
---

# Report a Bug

Bugs can be reported [here](https://bugs.launchpad.net/snappy-hwe-snaps/+filebug).

When submitting a bug report, please attach system log coming from the journal:

 * $ journalctl --no-pager > system-log

And the output of the following two commands:

```
$ nmcli d
$ nmcli c
```

It is a good idea to set the log level to DEBUG so that the verbose information
is provided. To do this for NetworkManager please see the [Logging Messages](logging-messages.md)
page.

If there is a modem and the modem-manager snap is installed, also add the output
of

```
$ sudo modem-manager.mmcli -m <N>
```

With being <N> the modem number as reported by

```
$ sudo modem-manager.mmcli -L
```
