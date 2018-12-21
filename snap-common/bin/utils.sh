#!/bin/sh -e

. /etc/lsb-release

get_target_system() {
    value=$(cat /proc/cmdline)

    case "$value" in
        *snap_core*)
            case "$DISTRIB_RELEASE" in
                *18*) echo "18" ;;
                *) echo "16" ;;
            esac
	    ;;
        *) echo "classic" ;;
    esac
}
