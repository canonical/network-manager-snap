#!/usr/bin/env python3
# -*- Mode:Python; indent-tabs-mode:nil; tab-width:4 -*-
#
# Copyright (C) 2016 Canonical Ltd
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

import os
import sys
import time
import random
import string
import urllib3
import zlib

from datetime import datetime

from argparse import ArgumentParser

import se_utils


def parseargs(argv):
    parser = ArgumentParser(prog='trigger-lp-build.py',
                            description="Build a specific snap on launchpad")
    parser.add_argument('-s', '--snap', required=True,
                        help="Name of the snap to build")
    parser.add_argument('-p', '--publish', action='store_true',
                        help="Trigger a publish build instead of a daily "
                        "(default)")
    parser.add_argument('-n', '--new', action='store_true',
                        help="Create a new ephemeral snap build on launchpad")
    parser.add_argument('--git-repo',
                        help="Git repository to be used for new ephemeral "
                        "snap build")
    parser.add_argument('--git-repo-branch',
                        help="Git repository branch to be used for new "
                        "ephemeral snap build")
    parser.add_argument('-a', '--architectures',
                        help="Specify architectures to build for. "
                        "Separate multiple architectures by ','")
    parser.add_argument('-r', '--results-dir',
                        help="Specify where results should be saved")
    parser.add_argument('--series',
                        help="Set Ubuntu series for the build")

    args = vars(parser.parse_args(argv))
    return args


def main(argv):
    args = parseargs(argv)

    ephemeral_build = False
    results_dir = os.path.join(os.getcwd(), "results")
    url_pool = urllib3.PoolManager()

    if 'results_dir' in args:
        results_dir = args['results_dir']

    if args['new']:
        ephemeral_build = True
        if args['git_repo'] is None or args['git_repo_branch'] is None:
            print("ERROR: No git repository or a branch supplied")
            sys.exit(1)

    series = 'xenial'
    if 'series' in args:
        series = args['series']

    lp_app = se_utils.get_config_option("lp_app")
    lp_env = se_utils.get_config_option("lp_env")
    credential_store_path = se_utils.get_config_option('credential_store_path')
    launchpad = se_utils.get_launchpad(None, credential_store_path,
                                       lp_app, lp_env)

    team = launchpad.people['snappy-hwe-team']
    ubuntu = launchpad.distributions['ubuntu']
    release = ubuntu.getSeries(name_or_version=series)
    primary_archive = ubuntu.getArchive(name='primary')

    snap = None
    if ephemeral_build:
        snap_arches = []
        if 'architectures' in args and args['architectures'] is not None:
            snap_arches = args["architectures"].split(",")

        if len(snap_arches) == 0:
            print("WARNING: No architectures to build specified. "
                  "Will only build for amd64.")
            snap_arches = ["amd64"]

        processors = []
        for arch in snap_arches:
            try:
                p = launchpad.processors.getByName(name=arch)
                processors.append(p.self_link)
            except Exception as ex:
                print("ERROR: Failed to find processor for '{}' "
                      "architecture: {}".format(arch, ex))
                sys.exit(1)

        build_name = 'ci-%s-%s' % (args["snap"],
                                   ''.join(random.choice(
                                       string.ascii_lowercase +
                                       string.digits) for _ in range(16)))
        print('Creating ephemeral snap recipe for "%s" series' % release)
        snap = launchpad.snaps.new(name=build_name,
                                   processors=processors,
                                   auto_build=False, distro_series=release,
                                   git_repository_url=args['git_repo'],
                                   git_path='%s' % args["git_repo_branch"],
                                   owner=team)
    else:
        build_name = "%s-daily" % args["snap"]
        if args["publish"] is True:
            build_name = "%s-publish" % args["snap"]
        snap = launchpad.snaps.getByName(name=build_name, owner=team)

    if snap is None:
        print("ERROR: Failed to create snap build on launchpad")

    # Not every snap is build against all arches.
    arches = [processor.name for processor in snap.processors]
    if not ephemeral_build and args['architectures'] is not None:
        wanted_arches = args["architectures"].split(",")
        possible_arches = []
        for arch in wanted_arches:
            if arch not in arches:
                print("WARNING: Can't build snap for architecture {} as it is"
                      "not enabled in the build job".format(args["snap"]))
                continue
            possible_arches.append(arch)
        arches = possible_arches

    if len(arches) == 0:
        print("ERROR: No architectures available to build for")
        sys.exit(1)

    # Add a big fat warning that we don't really care about fixing things when
    # the job will be canceled after the following lines are printed out.
    print("!!!!!!! POINT OF NO RETURN !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
    print("DO NOT CANCEL THIS JOB AFTER THIS OR BAD THINGS WILL HAPPEN")
    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

    stamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print("Trying to trigger builds at: {}".format(stamp))

    # sometimes we see error such as "u'Unknown architecture lpia for ubuntu
    # xenial'" and in order to workaround let's validate the arches agains set
    # of valid architectures that the snap can choose from

    # We will now trigger a build for each whitelisted architecture, collect
    # the build job url and the wait for all builds to finish and collect their
    # results to vote for a successful or failed build.
    triggered_builds = []
    triggered_build_urls = {}
    valid_arches = ['armhf', 'i386', 'amd64', 'arm64',
                    's390x', 'powerpc', 'ppc64el']
    for build_arch in arches:
        # sometimes we see error such as "u'Unknown architecture lpia for
        # ubuntu xenial'" and in order to workaround let's validate the arches
        # agains set of valid architectures that the snap can choose from
        if build_arch not in valid_arches:
            print("WARNING: Can't build snap for architecture {} as it is "
                  "not enabled in the build job".format(args["snap"]))
            continue

        arch = release.getDistroArchSeries(archtag=build_arch)
        if series == "xenial":
            request = snap.requestBuild(archive=primary_archive,
                                        channels={"snapcraft": "4.x/stable"},
                                        distro_arch_series=arch,
                                        pocket='Updates',
                                        snap_base='/+snap-bases/core')
        else:
            if series == 'bionic':
                # 6.0 onwards does not support i386, that we publish for core18
                snapcraft_chan = "5.x/stable"
            else:
                snapcraft_chan = "latest/stable"
            request = snap.requestBuild(archive=primary_archive,
                                        channels={"snapcraft": snapcraft_chan},
                                        distro_arch_series=arch,
                                        pocket='Updates')
        build_id = str(request).rsplit('/', 1)[-1]
        triggered_builds.append(build_id)
        triggered_build_urls[build_id] = request.self_link
        print("Arch: {} is building under: {}".format(build_arch,
                                                      request.self_link))

    failures = []
    successful = []
    while len(triggered_builds):
        tmp_builds = triggered_builds[:]
        for build in tmp_builds:
            try:
                response = snap.getBuildSummariesForSnapBuildIds(
                    snap_build_ids=[build])
            except Exception as ex:
                print("Could not get response for {} "
                      "(was there an LP timeout?): {}".format(build, ex))
                continue
            status = response[build]['status']
            if status == "FULLYBUILT":
                successful.append(build)
                triggered_builds.remove(build)
                continue
            elif status == "FAILEDTOBUILD":
                failures.append(build)
                triggered_builds.remove(build)
                continue
            elif status == "CANCELLED":
                print("INFO: {} snap build was canceled for id: {}".format(
                    args["snap"], build))
                triggered_builds.remove(build)
                continue

        if len(triggered_builds) > 0:
            time.sleep(60)

    if len(failures):
        for failure in failures:
            try:
                response = snap.getBuildSummariesForSnapBuildIds(
                    snap_build_ids=[failure])
            except Exception as ex:
                print("Could not get failure data for {} "
                      "(was there an LP timeout?): {}".format(build, ex))
                continue

            if failure not in response:
                print("Launchpad didn't returned us the snap build "
                      "summary we ask it for!?")
                continue

            build_summary = response[failure]
            arch = 'unknown'
            buildlog = None
            if 'build_log_url' in build_summary:
                buildlog = build_summary['build_log_url']

            if buildlog is not None and len(buildlog) > 0:
                parts = arch = str(buildlog).split('_')
                if len(parts) >= 4:
                    arch = parts[4]
            elif buildlog is None:
                buildlog = 'not available'

            print("INFO: {} snap {} build at {} failed for id: {} log: {}".
                  format(args["snap"], arch, stamp, failure, buildlog))

            # For ephermal builds we need to print out the log file as it will
            # be gone after the launchpad build is removed.
            if ephemeral_build and buildlog is not None:
                response = url_pool.request('GET', buildlog)
                log_data = zlib.decompress(response.data, 16+zlib.MAX_WBITS)
                print(log_data.decode("utf-8"))

    # Fetch build results for successful builds and store those in the output
    # directory so that the caller can reuse them.
    if len(successful):
        for success in successful:
            try:
                snap_build = launchpad.load(triggered_build_urls[success])
                urls = snap_build.getFileUrls()
                if len(urls):
                    for u in urls:
                        print("Downloading snap from %s ..." % u)
                        response = url_pool.request('GET', u)
                        if not os.path.exists(results_dir):
                            os.makedirs(results_dir)
                        path = os.path.join(results_dir, os.path.basename(u))
                        with open(path, "wb") as out_file:
                            out_file.write(response.data)
            except Exception as ex:
                print("Could not retrieve snap build data for {}"
                      "(was there an LP timeout?): {}".format(build, ex))
                continue

    if ephemeral_build:
        snap.lp_delete()

    if len(failures):
        # Let the build fail as at least a single snap has failed to build
        sys.exit(1)

    print("Done!")


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
