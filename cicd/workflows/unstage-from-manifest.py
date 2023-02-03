#!/usr/bin/python3
#
# Copyright (C) 2019 Canonical Ltd
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

# Script that removes some packages from the stage-packages sections in
# manifest files. Some times, pulled dependencies are not really staged
# for different reasons: libraries already in core, stuff that the deb
# needs but the snap does not, etc. This scripts helps as removing from
# the manifest so we do not get unneeded CVE notifications from the
# store.

import sys
from tools import yaml_utils


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def remove_from_staged(pkg_list_path, manifest_path, out_manifest_path):
    try:
        with open(pkg_list_path) as pkg_list_f:
            pkg_list = pkg_list_f.read().splitlines()
    except FileNotFoundError:
        print(pkg_list_path, 'not found, just copying manifest')
        pkg_list = []

    # We use snapcraft's yaml_utils so output looks the same as snapcraft's
    # and we can easily compare files.
    manifest_y = yaml_utils.load_yaml_file(manifest_path)

    # Loop looking for staged-packages per part, and removing packages
    # as requested.
    for part, part_y in manifest_y['parts'].items():
        aux_pkg = part_y['stage-packages'][:]
        for pkg in aux_pkg:
            # package_name=version
            pkg_data = pkg.split('=')
            if pkg_data[0] in pkg_list:
                part_y['stage-packages'].remove(pkg)

    with open(out_manifest_path, 'w') as out_manifest_f:
        yaml_utils.dump(manifest_y, stream=out_manifest_f)


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) != 3:
        eprint('Usage:', sys.argv[0], '<pkg_list_file> ' +
               '<manifest> <output_manifest>\n' +
               'where <pkg_list_file> is a file with a list of the packages ' +
               'to remove from stage-packages, one per line.')
        return 1
    pkg_list_path = argv[0]
    manifest_path = argv[1]
    out_manifest_path = argv[2]

    remove_from_staged(pkg_list_path, manifest_path, out_manifest_path)

    return 0


if __name__ == '__main__':
    sys.exit(main())
