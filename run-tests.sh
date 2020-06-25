#!/bin/bash
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

set -e

TESTS_EXTRAS_URL="https://git.launchpad.net/~snappy-hwe-team/snappy-hwe-snaps/+git/stack-snaps-tools"
TESTS_EXTRAS_PATH="tests-extras"

show_help() {
    exec cat <<'EOF'
Usage: run-tests.sh [OPTIONS]

This is fetch & forget script and what it does is to fetch the
stack-snaps-tools repository and execute the run-tests.sh script from
there passing arguments as-is.

When you see this message you don't have the tests-extras folder
successfully populated in your workspace yet. Please rerun without
specifying --help to proceed with the initial clone of the git repository.
EOF
}

# Clone the stack-snaps-tools repository
clone_tests_extras() {
	echo "INFO: Fetching stack-snaps-tools scripts into $TESTS_EXTRAS_PATH ..."
	if ! git clone -b master $TESTS_EXTRAS_URL $TESTS_EXTRAS_PATH >/dev/null 2>&1; then
		echo "ERROR: Failed to fetch the $TESTS_EXTRAS_URL repo, exiting.."
		exit 1
	fi
}

# Make sure the already cloned stack-snaps-tools repository is in a known and update
# state before it is going to be used.
restore_and_update_tests_extras() {
	echo "INFO: Restoring and updating $TESTS_EXTRAS_PATH"
	cd $TESTS_EXTRAS_PATH && git reset --hard && git clean -dfx && git pull
	cd -
}

# ==============================================================================
# This is fetch & forget script and what it does is to fetch the stack-snaps-tools
# repo and execute the run-tests.sh script from there passing arguments as-is.
#
# The stack-snaps-tools repository ends up checked out in the snap tree but as a
# hidden directory which is re-used since then.

# Find snap to use in the tests
snaps=$(find . -maxdepth 1 -type f -name \
             "*_*_$(dpkg-architecture -q DEB_HOST_ARCH).snap")
while read -r snap_file; do
    if [ -n "$snap" ]; then
        printf "More than one snap revision in the folder\n"
        exit 1
    fi
    snap=$PWD/${snap_file#*/}
done < <(printf "%s\n" "$snaps")

[ ! -d "$TESTS_EXTRAS_PATH" ] && [ "$1" = "--help" ] && show_help

if [ -d "$TESTS_EXTRAS_PATH" ]; then
	restore_and_update_tests_extras
else
	clone_tests_extras
fi

# Any project-specific options for test-runner should be specified in
# .tests_config under EXTRA_ARGS
if [ -f ".tests_config" ]; then
    # shellcheck disable=SC1091
    . .tests_config
fi

echo "INFO: Executing tests runner"
# shellcheck disable=SC2086
cd $TESTS_EXTRAS_PATH && ./tests-runner.sh "$@" --snap="$snap" $EXTRA_ARGS
