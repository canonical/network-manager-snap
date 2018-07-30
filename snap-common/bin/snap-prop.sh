#!/bin/sh -ex
# Copyright (C) 2016-2018 Canonical Ltd
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Getters for snap properties. They write the current value to stdout.

get_wifi_powersave() {
    value=$(snapctl get wifi.powersave)
    if [ -z "$value" ]; then
        value=disabled
    fi
    echo "$value"
}

get_wifi_wake_on_wlan() {
    value=$(snapctl get wifi.wake-on-wlan)
    if [ -z "$value" ]; then
        value=disabled
    fi
    echo "$value"
}

get_wifi_wake_on_password() {
    snapctl get wifi.wake-on-wlan-password
}

get_ethernet_enable() {
    value=$(snapctl get ethernet.enable)
    if [ -z "$value" ]; then
        # If this file was already present, assume NM is wanted to handle
        # ethernet in the device. Ideally this should be handled by setting
        # NM's ethernet.enable property in the gadget snap though.
        if [ -e /etc/netplan/00-default-nm-renderer.yaml ]; then
            value=true
        else
            value=false
        fi
    fi
    echo "$value"
}

get_debug_enable() {
    value=$(snapctl get debug.enable)
    if [ -z "$value" ]; then
        value=false
    fi
    echo "$value"
}
