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

import atexit
import sys
import time
import os
import yaml
from shutil import rmtree
from launchpadlib.credentials import RequestTokenAuthorizationEngine
from lazr.restfulclient.errors import HTTPError
from launchpadlib.launchpad import Launchpad
from launchpadlib.credentials import UnencryptedFileCredentialStore


class LaunchpadVote():
    APPROVE = 'Approve'
    DISAPPROVE = 'Disapprove'
    NEEDS_FIXING = 'Needs Fixing'


ACCESS_TOKEN_POLL_TIME = 10
WAITING_FOR_USER = """Open this link:
{}
to authorize this program to access Launchpad on your behalf.
Waiting to hear from Launchpad about your decision. . . ."""


class AuthorizeRequestTokenWithConsole(RequestTokenAuthorizationEngine):
    """Authorize a token in a server environment (with no browser).

    Print a link for the user to copy-and-paste into his/her browser
    for authentication.
    """

    def __init__(self, *args, **kwargs):
        # as implemented in AuthorizeRequestTokenWithBrowser
        kwargs['consumer_name'] = None
        kwargs.pop('allow_access_levels', None)
        super(AuthorizeRequestTokenWithConsole, self).__init__(*args, **kwargs)

    def make_end_user_authorize_token(self, credentials, request_token):
        """Ask the end-user to authorize the token in their browser.

        """
        authorization_url = self.authorization_url(request_token)
        print(WAITING_FOR_USER.format(authorization_url))
        # if we don't flush we may not see the message
        sys.stdout.flush()
        while credentials.access_token is None:
            time.sleep(ACCESS_TOKEN_POLL_TIME)
            try:
                credentials.exchange_request_token_for_access_token(
                    self.web_root)
                break
            except HTTPError as e:
                if e.response.status == 403:
                    # The user decided not to authorize this
                    # application.
                    raise e
                elif e.response.status == 401:
                    # The user has not made a decision yet.
                    pass
                else:
                    # There was an error accessing the server.
                    raise e


# launchpadlib is not thread/process safe so we are creating launchpadlib
# cache in /tmp per process which gets cleaned up at the end
# see also lp:459418 and lp:1025153
launchpad_cachedir = os.path.join('/tmp', str(os.getpid()), '.launchpadlib')

# `launchpad_cachedir` is leaked upon unexpected exits
# adding this cleanup to stop directories filling up `/tmp/`
atexit.register(rmtree, os.path.join('/tmp',
                str(os.getpid())),
                ignore_errors=True)


def get_launchpad(launchpadlib_dir=None, credential_store_path=None,
                  lp_app=None, lp_env=None):
    """ return a launchpad API class. In case launchpadlib_dir is
    specified used that directory to store launchpadlib cache instead of
    the default """
    store = UnencryptedFileCredentialStore(credential_store_path)
    authorization_engine = AuthorizeRequestTokenWithConsole(lp_env, lp_app)
    lib_dir = launchpad_cachedir
    if launchpadlib_dir is not None:
        lib_dir = launchpadlib_dir
    return Launchpad.login_with(lp_app, lp_env,
                                credential_store=store,
                                authorization_engine=authorization_engine,
                                launchpadlib_dir=lib_dir,
                                version='devel')


# Load configuration for the current agent we're running on. All agents were
# provisioned when they were setup with a proper configuration. See
# https://wiki.canonical.com/InformationInfrastructure/Jenkaas/UserDocs for
# more details.
def load_config():
    files = [os.path.expanduser('~/.jlp/jlp.config'), 'jlp.config']
    for config_file in files:
        try:
            config = yaml.safe_load(open(config_file, 'r'))
            return config
        except IOError:
            pass
    print("ERROR: No config file found")
    sys.exit(1)


# Return a configuration option from the agent configuration specified by the
# name argument.
def get_config_option(name):
    config = load_config()
    return config[name]


def get_branch_handle_from_url(lp_handle, url):
    """ Return a branch/repo handle for the given url.
    Returns a launchpad branch or git repository handle for the given url.
    :param lp_handle: launchpad API handle/instance
    :param url: url of the branch or git repository
    """
    if '+git' in url:
        name = url.replace('https://code.launchpad.net/', '')
        print('fetching repo: ' + name)
        try:
            return lp_handle.git_repositories.getByPath(path=name)
        except AttributeError:
            print('git_repositories.getByPath was not found. ' +
                  'You may need to set lp_version=devel in the config')
            return None
    else:
        name = url.replace('https://code.launchpad.net/', 'lp:')
        name = name.replace('https://code.staging.launchpad.net/',
                            'lp://staging/')
        print('fetching branch: ' + name)
        return lp_handle.branches.getByUrl(url=name)
