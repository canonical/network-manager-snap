---
title: "NetworkManager and netplan"
table_of_contents: False
---

# NetworkManager and netplan

The default netplan configuration files in Ubuntu Core leave
management of networking devices to networkd. But, when
network-manager is installed, it creates new netplan configuration
files, setting itself as the default network renderer and taking
control of all devices.

It is possible to control this behavior with the `defaultrenderer`
snap option. It is set by default to `true`, but if we set it to
`false`, network-manager reverts the netplan configuration and
networkd takes control of the devices again. Note however that
networkd will take control only of devices explicitly configured by
netplan configuration files, which is usually only ethernet or wifi
devices. To do that:

```
snap set network-manager defaultrenderer=false
```

In the core16 snap (legacy), the behavior was different: networkd was
left as default renderer and the default netplan configuration was
unchanged when network-manager was installed. There was instead a
setting called `ethernet.enable` that was `false` by default. When set
to `true`, NetworkManager was set as the default network renderer
similarly as described above.
