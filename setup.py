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
from os.path import join
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

parser = argparse.ArgumentParser('LHCb stack setup')
parser.add_argument('path', help='Path to stack directory',
                    **({'nargs': '?'} if FROM_FILE else {}))
parser.add_argument('--repo', '-u', default=REPO, help='Repository URL')
parser.add_argument('--branch', '-b', default=BRANCH, help='Branch')
parser.add_argument('--debug', action='store_true', help='Debugging output')
args = parser.parse_args()

logging.basicConfig(format='%(levelname)-7s %(message)s',
                    level=(logging.DEBUG if args.debug else logging.INFO))

if not args.path:
    args.path = os.path.abspath(join(os.path.dirname(__file__), '..'))
    logging.info('Guessed path to stack: {}'.format(args.path))

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

stack_dir = args.path
utils_dir = join(stack_dir, 'utils')
config_file = join(utils_dir, 'config')
update_setup = False

try:
    os.mkdir(stack_dir)
except OSError as e:
    if e.errno == errno.EEXIST:
        if os.listdir(stack_dir):
            update_setup = True
            logging.info('Updating existing stack setup in {}'
                         .format(stack_dir))
    else:
        sys.exit('Could not create directory {!r}: {!s}'
                 .format(stack_dir, e.strerror))

if update_setup:
    sys.exit('Updating not implemented yet. '
             'Please update manually with git pull in utils.')

check_call([GIT, 'clone', '-q', args.repo, join(stack_dir, 'utils')])
check_call([GIT, 'checkout', '-q', args.branch], cwd=join(stack_dir, 'utils'))
check_call([join(utils_dir, 'config.py'), 'useDocker', str(use_docker).lower()])
# the target needs to be relative
os.symlink(join('utils', 'Makefile'), join(stack_dir, 'Makefile'))

# TODO check free space and warn?

logging.info("""
Now do

    cd "{!s}"
    $EDITOR utils/config.json
    $EDITOR utils/configuration.mk
    bash utils/install.sh
    make

""".format(stack_dir)
)
