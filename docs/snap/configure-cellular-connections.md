---
title: "Configure Cellular Connections"
table_of_contents: False
---

# Configure Cellular Connections

For cellular connections, first install the modem-manager snap with:
```
$ snap install modem-manager
```

Check whether a modem was properly detected via:

```
$ sudo modem-manager.mmcli -L
Found 1 modems:
	/org/freedesktop/ModemManager1/Modem/0 [description]
```

In this case we have just one modem, with index 0 (the number at the end of the DBus object path).

Show detailed information about the modem using that index:

```
$ sudo modem-manager.mmcli -m 0
/org/freedesktop/ModemManager1/Modem/0 (device id '871faa978a12ccb25b9fa30d15667571ab38ed88')
  -------------------------
  Hardware |   manufacturer: 'ZTE INCORPORATED'
           |          model: 'MF626'
           |       revision: 'MF626V1.0.0B06'
           |      supported: 'gsm-umts'
           |        current: 'gsm-umts'
           |   equipment id: '357037039840195'
  -------------------------
  System   |         device: '/sys/devices/pci0000:00/0000:00:01.2/usb1/1-1'
           |        drivers: 'option1'
           |         plugin: 'ZTE'
           |   primary port: 'ttyUSB3'
           |          ports: 'ttyUSB0 (qcdm), ttyUSB1 (at), ttyUSB3 (at)'
  -------------------------
  Numbers  |           own : 'unknown'
  -------------------------
  Status   |           lock: 'sim-pin'
           | unlock retries: 'sim-pin (3), sim-puk (10)'
           |          state: 'locked'
           |    power state: 'on'
           |    access tech: 'unknown'
           | signal quality: '0' (cached)
  -------------------------
  Modes    |      supported: 'allowed: any; preferred: none'
           |        current: 'allowed: any; preferred: none'
  -------------------------
  Bands    |      supported: 'unknown'
           |        current: 'unknown'
  -------------------------
  IP       |      supported: 'none'
  -------------------------
  SIM      |           path: '/org/freedesktop/ModemManager1/SIM/0'

  -------------------------
  Bearers  |          paths: 'none'
```

In this case we can see that the SIM has PIN locking enabled and its state is
‘locked’. To enter the PIN, we need to know the SIM index, which in this
case is 0 (it is the number at the end of /org/freedesktop/ModemManager1/SIM/0).
Once the index is known, we can enter the SIM PIN with:

```
$ sudo modem-manager.mmcli -i 0 --pin=<PIN>
successfully sent PIN code to the SIM
```

Some more commands for handling SIM PINs include:

```
$ sudo modem-manager.mmcli -i 0 --pin=<PIN> --enable-pin
$ sudo modem-manager.mmcli -i 0 --pin=<PIN> --disable-pin
$ sudo modem-manager.mmcli -i 0 --pin=<PIN> --change-pin=<NEW_PIN>
$ sudo modem-manager.mmcli -i 0 --puk=<PUK>
```

Which respectively enables PIN locking, disables PIN locking, changes the PIN code,
and unlocks a [PUK](https://en.wikipedia.org/wiki/Personal_unblocking_code)-locked SIM.

After that we can add a cellular connection with:

```
$ nmcli c add type gsm ifname <interface> con-name <name> apn <operator_apn>
$ nmcli r wwan on
```

where &lt;interface&gt; is the string listed as “primary port” in the
output from `sudo mmcli -m <N>` (as previously described),
&lt;name&gt; is an arbitrary name used to identify the connection, and
&lt;operator_apn&gt; is the APN name for your cellular data plan.
Note that &lt;interface&gt; is usually a serial port with pattern
tty\* or a cdc-wdm\* device, not a networking interface. As these
interface names might change depending on the devices present in the
system, a better alternative is to use the sysfs path shown by mmcli
(device: ...) or use `'*'`, which will use any modem device detected
by MM:

```
sudo nmcli c add type gsm ifname '*' con-name <name> apn <operator_apn>
```

After executing these commands, NetworkManager will automatically try to bring up
the cellular connection whenever ModemManager reports that the modem has
registered (the state of the modem can be checked with the previously introduced
command “sudo modem-manager.mmcli -m &lt;N&gt;”). When done successfully, NetworkManager
will create routes for the new network interface, with less priority than
Ethernet or WiFi interfaces. To disable the connection, we can do:

```
$ nmcli r wwan off
```

or change the autoconnect property and turn the connection off if we need more
fine-grained control:

```
$ nmcli c modify <name> connection.autoconnect [yes|no]
$ nmcli c down <name>
```

Finally, note that we can provide the PIN (so it is entered
automatically) or additional APN provisioning information when
creating/modifying the WWAN connection.  For instance:

```
$ nmcli c add type gsm ifname <interface> con-name <name> apn <operator_apn> username <user> password <password> pin <PIN>
```
