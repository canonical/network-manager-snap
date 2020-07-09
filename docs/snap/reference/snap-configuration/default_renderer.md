---
title: Default renderer
table_of_contents: true
---

# Default renderer

The NetworkManager snap provides a configuration option,
`defaultrenderer`, to adjust if it should be the default network
renderer or not. By default, it is set to `true`. To change it:

```
snap set network-manager defaultrenderer=false
```

For the core16 snap, there is an option called `ethernet.enable` that
does basically the same. See the [NetworkManager and netplan](../../networkmanager-and-netplan.md)
section for more details.
