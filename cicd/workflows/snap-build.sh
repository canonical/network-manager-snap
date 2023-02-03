#!/bin/bash
#
# Copyright (C) 2017 Canonical Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -exu

# Used external variables
REPOSITORY=$GITHUB_REPOSITORY
BRANCH=$GITHUB_HEAD_REF

script_name=${0##*/}
CICD_SCRIPTS=${0%%"$script_name"}

# shellcheck source=common.sh
. "$CICD_SCRIPTS"/common.sh

# Build snap using launchpad
# $1: path where built snaps are downloaded
main()
{
    local build_d=$1

    # Find out snap name
    local snapcraft_yaml_p
    snapcraft_yaml_p=$(get_snapcraft_yaml_path)
    if [ -z "$snapcraft_yaml_p" ]; then
        printf "ERROR: No snapcraft.yaml found. Not trying to build anything\n"
        exit 1
    fi

    # TODO replace with jq
    local snap_name series
    snap_name=$(grep -v ^\# "$snapcraft_yaml_p" |
                    head -n 5 | grep "^name:" | awk '{print $2}')
    series=$(get_series "$snapcraft_yaml_p")

    build_and_download_snaps "$snap_name" \
                             https://github.com/"$REPOSITORY".git \
                             "$BRANCH" "$series" "$build_d"
}

if [ $# -ne 1 ]; then
    printf "Wrong number of arguments.\n"
    printf "Usage: %s <build_dir>\n" "$0"
    exit 1
fi
main "$1"
