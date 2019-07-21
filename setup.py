#!/usr/bin/env python
from __future__ import print_function
import sys

if sys.version_info < (2, 7):
    sys.exit("Python 2.7 or later is required.")

import argparse
import logging
import os
import errno
import platform
import warnings
from os.path import join, realpath
from subprocess import check_call, check_output, CalledProcessError
from distutils.version import LooseVersion

FROM_FILE = os.path.isfile(__file__)
CVMFS_DIRS = [
    # (path, mandatory)
    ('/cvmfs/lhcb.cern.ch', True),
    ('/cvmfs/lhcb-condb.cern.ch', True),
    ('/cvmfs/lhcbdev.cern.ch', False),
    ('/cvmfs/sft.cern.ch', False),
]
CVMFS_GIT = '/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin/git'
GIT = 'git'
URL_BASE = 'https://gitlab.cern.ch/rmatev/lb-stack-setup'
REPO = URL_BASE + '.git'
BRANCH = 'master'
# TODO test that url and branch matches repo in a CI test?


def is_stack_dir(path):
    """Returns if path was setup the way we expect."""
    path = realpath(path)
    utils = join(path, 'utils')
    return (
        os.path.isdir(join(utils, '.git')) and
        realpath(join(path, 'Makefile')) == join(utils, 'Makefile'))


parser = argparse.ArgumentParser('LHCb stack setup')
parser.add_argument('path', help='Path to stack directory',
                    **({'nargs': '?'} if FROM_FILE else {}))
parser.add_argument('--repo', '-u', default=REPO, help='Repository URL')
parser.add_argument('--branch', '-b', default=BRANCH, help='Branch')
parser.add_argument('--debug', action='store_true', help='Debugging output')
# TODO add list of projects?
args = parser.parse_args()

logging.basicConfig(format='%(levelname)-7s %(message)s',
                    level=(logging.DEBUG if args.debug else logging.INFO))


stack_dir = args.path or realpath(join(os.path.dirname(__file__), '..'))
utils_dir = join(stack_dir, 'utils')

new_setup = True
if os.path.isdir(stack_dir):
    if is_stack_dir(stack_dir):
        logging.info('Found existing stack at {}'.format(stack_dir))
        new_setup = False
    else:
        parser.error('directory {} exists but does not look like a stack setup'
                     .format(stack_dir))
elif not args.path:
    parser.error('path was not provided and it could not be guessed')


# Check CVMFS
inaccessible_dirs = False
for path, mandatory in CVMFS_DIRS:
    try:
        if not os.listdir(path):
            logging.error('Directory {!r} is empty'.format(path))
            inaccessible_dirs = True
    except (OSError, RuntimeError) as e:
        msg = 'Directory {!r} is not accessible: {!s}'.format(path, str(e))
        if not mandatory:
            logging.warning(msg)
        else:
            logging.error(msg)
            inaccessible_dirs = True
if inaccessible_dirs:
    sys.exit('Some needed directories are not accessible.\n'
             'Check {}/blob/master/doc/prerequisites.md'.format(URL_BASE))

# Check host OS
host_os = (check_output('/cvmfs/lhcb.cern.ch/lib/bin/host_os')
	   .decode('ascii').strip())
use_docker = False
if host_os == 'x86_64-centos7':
    # test native setup
    pass
else:
    logging.info('Platform {!s} is not supported natively, '
                 'checking for docker...'.format(host_os))
    try:
        check_output(['docker', 'run', '--rm', 'hello-world'])
    except CalledProcessError as e:
        sys.exit('Docker not available or not set up correctly.')
    logging.info('...using docker.')
    use_docker = True

# Check git version and suggest alias if too old
git_ver_str = check_output(['git', '--version']).decode('ascii').strip()
git_ver = LooseVersion(git_ver_str.split()[2])
if git_ver < LooseVersion('2.13'):
    logging.warning('Old unspported git version {} detected. Consider using\n'
                    '    alias git={}'.format(git_ver, CVMFS_GIT))

# TODO check free space and warn? Do it smartly base on selected projects?

# Do the actual new setup or update
def git(*args_):
    quiet = [] if args.debug else ['--quiet']
    cwd = utils_dir if args_[0] != 'clone' else None
    cmd = [GIT] + list(args_[:1]) + quiet + list(args_[1:])
    logging.debug('Executing command (cwd = {}): {}'
                  .format(cwd, ' '.join(map(repr, cmd))))
    check_call(cmd, cwd=cwd)

if new_setup:
    logging.info('Creating new stack setup in {} ...'.format(stack_dir))
    os.mkdir(stack_dir)
    git('clone', args.repo, utils_dir)
    git('checkout', args.branch)
    # the target needs to be relative
    os.symlink(join('utils', 'Makefile'), join(stack_dir, 'Makefile'))
else:
    logging.info('Updating existing stack setup in {} from branch origin/{} ...'
                 .format(stack_dir, args.branch))
    # Check if it is okay to update
    try:
        git('pull' , '--ff-only', 'origin', args.branch)
    except CalledProcessError:
        logging.warning('Could not "git pull" cleanly. Check for uncommited changes.')

sys.path.insert(0, utils_dir)
from config import read_config, write_config, CONFIG

overrides = read_config(True)[2]
if new_setup:
    overrides['useDocker'] = use_docker
    write_config(overrides)
    logging.info("""
Now do

    cd "{!s}"
    $EDITOR utils/config.json
    $EDITOR utils/configuration.mk
    make

""".format(stack_dir))
else:
    # Obtain configuration ignoring config.json
    new_overrides = read_config(True, config_in=None)[2]
    new_overrides['useDocker'] = use_docker
    # Try to merge configuration
    config_out = CONFIG
    for key, new_value in new_overrides.items():
        if overrides.get(key, new_value) != new_value:
            config_out = join(os.path.dirname(CONFIG), 'config-new.json')
            logging.warning(
                'Could not merge new automatic config with your config.json\n'
                'Please merge config-new.json into config.json manually.')
            break
        overrides[key] = new_value
    write_config(overrides, config_out)
    logging.info('Stack updated successfully.')
