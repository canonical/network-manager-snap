#!/bin/bash -ex
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

# Set common variables used by the jenkins jobs
# set_jenkins_env ()
# {
#     SSH_PATH="${JENKINS_HOME}/.ssh/"
#     SSH_KEY_PATH="${SSH_PATH}/bazaar.launchpad.net/system-enablement-ci-bot"

#     SSH="ssh -i $SSH_KEY_PATH/id_rsa $REMOTE_USER@$REMOTE_WORKER"
#     SCP="scp -i $SSH_KEY_PATH/id_rsa"

#     REPO=https://git.launchpad.net/~snappy-hwe-team/snappy-hwe-snaps/+git/$CI_REPO
#     BRANCH=$CI_BRANCH

#     # If no CI repo/branch is set fallback to the source repo/branch set
#     # which will be the case for those repositories which don't contain
#     # a snap.
#     if [ -z "$CI_REPO" ]; then
#         REPO=$SOURCE_GIT_REPO
#         BRANCH=$SOURCE_GIT_REPO_BRANCH
#     fi

#     REMOTE_WORKSPACE=/home/$REMOTE_USER/$BUILD_TAG
#     REMOTE_RESULTS_BASE_DIR=/home/$REMOTE_USER/results
# }

# Sets variables
# TEST_TYPE={script, spread}
# HW_TESTS_RESULT={0, !=0} -> {has hw tests, does not have hw tests}
# FIXME Maybe depending on context the call to clone could be avoided
# set_test_type ()
# {
#     tmp_srcdir=$(mktemp -d)

#     # We use FAIL to make sure we do not exit until we free tmp_srcdir
#     FAIL=no
#     git clone --depth 1 -b "$BRANCH" "$REPO" "$tmp_srcdir"/src || FAIL=yes
#     cd "$tmp_srcdir"/src || FAIL=yes

#     TEST_TYPE=none
#     if [ -e "$tmp_srcdir/src/spread.yaml" ]; then
#         TEST_TYPE=spread
#     fi
#     # run-tests.sh gets priority over spread.yaml
#     if [ -e "$tmp_srcdir/src/run-tests.sh" ]; then
#         TEST_TYPE=script
#     fi

#     # TODO: Use https://github.com/0k/shyaml in the future for this
#     if grep -q "type: adhoc" spread.yaml; then
#         HW_TESTS_RESULT=0
#     else
#         HW_TESTS_RESULT=1
#     fi

#     # Components have the ability to disable CI tests if they can't provide any.
#     # This is only accepted in a few cases and should be generally avoided.
#     CI_TESTS_DISABLED=no
#     if [ -e "$tmp_srcdir"/src/.ci_tests_disabled ]; then
#         CI_TESTS_DISABLED=yes
#     fi

#     rm -rf "$tmp_srcdir"

#     if [ "$FAIL" = yes ]; then
#         echo "ERROR: critical in set_test_type()"
#         exit 1
#     fi

#     if [ "$CI_TESTS_DISABLED" = yes ]; then
#         echo "WARNING: Component has no CI tests so not running anything here"
#         exit 0
#     fi

#     if [ "$TEST_TYPE" = none ]; then
#         echo "ERROR: missing spread or script tests: you must provide one of them"
#         exit 1
#     fi
# }

# Creates and downloads the snaps for the supported architectures
# $1: snap name
# $2: repository url (launchpad API does not accept git+ssh)
# $3: release branch
# $4: ubuntu series
# $5: results folder
build_and_download_snaps()
{
    local snap_n=$1
    local repo_url=$2
    local release_br=$3
    local series=$4
    local results_d=$5

    # Starting with core20/focal, i386 is not supported
    if [ "$series" = xenial ] || [ "$series" = bionic ]; then
        archs=i386,amd64,armhf,arm64
    else
        # TODO riscv64?
        archs=amd64,armhf,arm64
    fi

    # Build snap without publishing it to get the new manifest.
    # TODO we should leverage it to run tests as well
    "$CICD_SCRIPTS"/trigger-lp-build.py \
                    -s "$snap_n" -n \
                    --architectures="$archs" \
                    --git-repo="$repo_url" \
                    --git-repo-branch="$release_br" \
                    --results-dir="$results_d" \
                    --series="$series"
}

# Inject or remove files in a snap
# $1: path to snap
# Following arguments are pairs of:
# $n: path to file to inject, empty if we want to remove instead
# $n+1: path inside snap of the file to inject/remove
modify_files_in_snap()
{
    local snap_p=$1
    shift 1
    local fs_d dest_d user_group i

    fs_d=squashfs
    unsquashfs -d "$fs_d" "$snap_p"

    i=1
    while [ $i -le $# ]; do
        local orig_p dest_p
        orig_p=${!i}
        i=$((i + 1))
        dest_p=${!i}
        i=$((i + 1))
        if [ -n "$orig_p" ]; then
            dest_d="$fs_d"/${dest_p%/*}
            dest_f=${dest_p##*/}
            mkdir -p "$dest_d"
            cp "$orig_p" "$dest_d/$dest_f"
        else
            rm -f "$fs_d/$dest_p"
        fi
    done

    rm "$snap_p"
    snap pack --filename="$snap_p" "$fs_d"
    rm -rf "$fs_d"
}

# Login to the snap store
snap_store_login()
{
    # No need to log-in anymore as we use SNAPCRAFT_STORE_CREDENTIALS.
    # However, we print id information here as that includes expiration
    # date for the credentials, which can be useful.
    _run_snapcraft whoami
}

_run_snapcraft()
{
    http_proxy="$PROXY_URL" https_proxy="$PROXY_URL" snapcraft "$@"
}

# Logout of the snap store
snap_store_logout()
{
    # Doing logout does not make sense anymore as we use
    # SNAPCRAFT_STORE_CREDENTIALS env var. We keep the function as it
    # might be useful in the future.
    true
}

# Pushes and releases snaps in a folder for the given channel
# $1: directory with snaps
# $2: snap name
# $3,...,$n: channels
push_and_release_snap()
(
    local snaps_d=$1
    local snap_n=$2
    shift 2
    local channels=$*
    channels=${channels// /,}
    local snap_file

    cd "$snaps_d"
    for snap_file in "$snap_n"_*.snap; do
        _run_snapcraft upload "$snap_file" --release "$channels"
    done
)

# Return path to snapcraft.yaml. Run inside repo.
get_snapcraft_yaml_path()
{
    if [ -f snapcraft.yaml ]; then
        printf snapcraft.yaml
    elif [ -f snap/snapcraft.yaml ]; then
        printf snap/snapcraft.yaml
    fi
}

# Get snap series from snapcraft.yaml
# $1: path to snapcraft.yaml
get_series()
{
    local base
    base=$(grep -oP '^base:[[:space:]]+core\K\w+' "$1") || true
    if [ "$base" -eq 22 ]; then
        printf jammy
    elif [ "$base" -eq 20 ]; then
        printf focal
    elif [ "$base" -eq 18 ]; then
        printf bionic
    else
        printf xenial
    fi
}

# Get track from branch, assuming it is of the form <name>-<track>
# $1: branch
get_track_from_branch()
{
    local branch=$1
    local branch_sufix
    # If there is no '-', branch_sufix will be equal to branch
    branch_sufix=${branch##*-}
    if [ "$branch_sufix" !=  "$branch" ]; then
        printf %s "$branch_sufix"
    else
        printf latest
    fi
}
