#!/bin/sh -eu
# Copyright (C) 2022 Canonical Ltd
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

# Ensure we have a compatible version of MM, if present in the system
if version=$(dbus-send --system --print-reply=literal --dest=org.freedesktop.ModemManager1 /org/freedesktop/ModemManager1 org.freedesktop.DBus.Properties.Get string:"org.freedesktop.ModemManager1" string:"Version"); then
    version=$(printf "%s" "$version" | awk '{print $2;}')
    req_version=1.18
    older_version=$(printf "%s\n%s" "$req_version" "$version" | sort -V | head -n1)
    if [ "$req_version" != "$older_version" ]; then
        printf "ERROR: %s version of ModemManager detected, while %s or newer needed.\n" \
               "$version" "$req_version" 1>&2
        printf "Please install a newer version of ModemManager and retry.\n" 1>&2
        exit 1
    fi
fi

exit 0
