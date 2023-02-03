#!/usr/bin/env python3
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

from argparse import ArgumentParser

import se_utils

print("Running delete-ci-repo")

parser = ArgumentParser(description="Delete a git repository stored in launchpad")
parser.add_argument('--git-repo', help="Git repository to be deleted")

args = vars(parser.parse_args())

git_repo = args['git_repo']
ind = git_repo.find('~')
if ind == -1:
    print("Bad git repo {}".format(git_repo))
    exit(1)

lp_repo = git_repo[ind:]

lp_app = se_utils.get_config_option("lp_app")
lp_env = se_utils.get_config_option("lp_env")
credential_store_path = se_utils.get_config_option('credential_store_path')
launchpad = se_utils.get_launchpad(None, credential_store_path, lp_app, lp_env)

repo = launchpad.git_repositories.getByPath(path=lp_repo)
print("Removing {}".format(lp_repo))
repo.lp_delete()
