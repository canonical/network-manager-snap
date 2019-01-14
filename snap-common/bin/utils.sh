#!/bin/sh -e

. /etc/lsb-release

get_series_major_version() {
    printf "%s\n" "${DISTRIB_RELEASE%%.*}"
}
