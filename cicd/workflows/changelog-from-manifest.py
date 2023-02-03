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

# Script that compares two manifest.yaml files and creates a paragraph
# that includes the changes for all deb files. These changes are
# obtained from the debian changelog for the different packages.

import debian.changelog
import debian.debian_support
import gzip
import requests
import sys
import yaml
from collections import namedtuple


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


# Returns a dictionary from package name to version, using
# stage-packages section.
# manifest_y: yaml document with manifest
def get_staged_version_from_yaml(manifest_y):
    staged_v = {}
    for part, part_y in manifest_y['parts'].items():
        for pkg in part_y['stage-packages']:
            # package_name=version
            pkg_data = pkg.split('=')
            staged_v[pkg_data[0]] = pkg_data[1]

    return staged_v


# Returns a dictionary from package name to version, using
# primed-stage-packages section.
# manifest_y: yaml document with manifest
def get_primed_version_from_yaml(manifest_y):
    primed_v = {}
    for pkg in manifest_y['primed-stage-packages']:
        # package_name=version
        pkg_data = pkg.split('=')
        primed_v[pkg_data[0]] = pkg_data[1]

    return primed_v


# Returns a dictionary from package name to version, using
# primed-stage-packages section if available, otherwise calling
# get_staged_version.
# manifest_p: path to manifest to load
def get_primed_version(manifest_p):
    with open(manifest_p) as manifest:
        manifest_y = yaml.safe_load(manifest)

    if 'primed-stage-packages' in manifest_y:
        return get_primed_version_from_yaml(manifest_y)
    else:
        return get_staged_version_from_yaml(manifest_y)


def get_changelog_from_file(docs_d, pkg):
    chl_path = docs_d + '/' + pkg + '/changelog.Debian.gz'
    with gzip.open(chl_path) as chl_fh:
        return chl_fh.read().decode('utf-8')


def get_changelog_from_url(pkg, new_v):
    url = 'https://changelogs.ubuntu.com/changelogs/binary/'
    if pkg.startswith('lib'):
        url += pkg[0:4]
    else:
        url += pkg[0]
    url += '/' + pkg + '/' + new_v + '/changelog'
    changelog_r = requests.get(url)
    if changelog_r.status_code != requests.codes.ok:
        raise Exception('No changelog found in ' + url + ' - status:' +
                        str(changelog_r.status_code))

    return changelog_r.text


# Gets difference in changelog between old and new versions
# Returns source package and the differences
def get_changes_for_version(docs_d, pkg, old_v, new_v, indent):
    # Try to get changelog from file (only option that will work for
    # ESM packages), otherwise go to changelogs.ubuntu.com.
    try:
        changelog = get_changelog_from_file(docs_d, pkg)
    except Exception:
        changelog = get_changelog_from_url(pkg, new_v)

    source_pkg = changelog[0:changelog.find(' ')]

    chl = debian.changelog.Changelog(changelog)
    old_deb_v = debian.debian_support.Version(old_v)
    for version in chl.get_versions():
        vc = debian.debian_support.version_compare(old_deb_v, version)
        if vc >= 0:
            break

    # Get the changelog chunk since the version older or equal to old_v
    change_chunk = ''
    old_change_start = source_pkg + ' (' + version.__str__() + ')'
    for line in changelog.splitlines():
        if line.startswith(old_change_start):
            break
        if line == '':
            change_chunk += '\n'
        else:
            change_chunk += indent + line + '\n'

    return source_pkg, change_chunk


# Returns the changes related to primed packages between two manifests
# old_manifest_p: path to old manifest
# new_manifest_p: path to newer manifest
# docs_d: directory with docs from debian packages
def compare_manifests(old_manifest_p, new_manifest_p, docs_d):
    old_primed_v = get_primed_version(old_manifest_p)
    new_primed_v = get_primed_version(new_manifest_p)
    changes = ''

    src_pkgs = {}
    SrcPkgData = namedtuple('SrcPkgData', 'old_v new_v changes debs')
    for pkg, new_v in sorted(new_primed_v.items()):
        try:
            old_v = old_primed_v[pkg]
            if old_v != new_v:
                (src, pkg_change) = get_changes_for_version(docs_d, pkg, old_v,
                                                            new_v, '  ')
                if src not in src_pkgs:
                    src_pkgs[src] = SrcPkgData(old_v, new_v, pkg_change, [pkg])
                else:
                    src_pkgs[src].debs.append(pkg)
        except KeyError:
            changes += pkg + ' (' + new_v + '): new primed package\n\n'

    for src_pkg, pkg_data in sorted(src_pkgs.items()):
        changes += ', '.join(pkg_data.debs)
        changes += ' (built from ' + src_pkg + ') updated from '
        changes += pkg_data.old_v + ' to ' + pkg_data.new_v + ':\n\n'
        changes += pkg_data.changes

    for pkg, old_v in sorted(old_primed_v.items()):
        if pkg not in new_primed_v:
            changes += pkg + ': not primed anymore\n\n'

    return changes


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]

    if len(argv) != 3:
        eprint('Usage:', sys.argv[0],
               '<old_manifest> <new_manifest> <docs_dir>')
        return 1
    old_manifest = argv[0]
    new_manifest = argv[1]
    docs_dir = argv[2]

    changes = '[ Changes in primed packages ]\n\n'
    pkg_changes = compare_manifests(old_manifest, new_manifest, docs_dir)
    if pkg_changes != '':
        changes += pkg_changes
    else:
        changes += 'No changes for primed packages\n\n'
    print(changes, end='')
    return 0


if __name__ == '__main__':
    sys.exit(main())
