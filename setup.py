#!/usr/bin/env python
from __future__ import print_function
import sys

if sys.version_info < (2, 7):
    sys.exit("Python 2.7 or later is required.")

import argparse
import os
import errno
import warnings
from os.path import join
from subprocess import check_call, check_output, CalledProcessError
from distutils.version import LooseVersion

FROM_FILE = os.path.isfile(__file__)
CVMFS_DIRS = [
    # (path, mandatory)
    ('/cvmfs/lhcb.cern.ch', True),
    ('/cvmfs/lhcbdev.cern.ch', False),
    ('/cvmfs/sft.cern.ch', False),
]
GIT = '/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin/git'
REPO = 'https://gitlab.cern.ch/rmatev/lb-stack-setup.git'
BRANCH = 'master'
# TODO test that url and branch matches repo in a CI test?

parser = argparse.ArgumentParser('LHCb stack setup')
parser.add_argument('path', help='Path to stack directory',
                    **({'nargs': '?'} if FROM_FILE else {}))
args = parser.parse_args()

if not args.path:
    args.path = os.path.abspath(join(os.path.dirname(__file__), '..'))
    print('Guessed path to stack: {}'.format(args.path))

for path, mandatory in CVMFS_DIRS:
    try:
        if not os.listdir(path):
            raise RuntimeError('Directory {!r} is empty'.format(path))
    except (OSError, RuntimeError) as e:
        msg = 'Directory {!r} is not accessible: {!s}'.format(path, str(e))
        if not mandatory:
            warnings.warn(msg)
        raise RuntimeError(msg)

# Check host OS
host_os = check_output('/cvmfs/lhcb.cern.ch/lib/bin/host_os').strip()
use_docker = False
if host_os == b'x86_64-centos7':
    # test native setup
    pass
else:
    print('Platform {!s} is not supported natively, checking for docker...'
          .format(host_os))
    try:
        check_output(['docker', 'run', '--rm', 'hello-world'])
    except CalledProcessError as e:
        sys.exit('Docker not available or not set up correctly.')
    print('...using docker.')
    use_docker = True

# Check git version and suggest alias if too old
git_ver_str = check_output(['git', '--version'])
git_ver = LooseVersion(git_ver_str.split()[2])
if git_ver < LooseVersion('2.13'):
    print('Old unspported git version {} detected. Consider using\n'
          '    alias git={}'.format(git_ver, GIT))

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
            print('Updating existing stack setup in {}'.format(stack_dir))
    else:
        sys.exit('Could not create directory {!r}: {!s}'
                 .format(stack_dir, e.strerror))

if update_setup:
    sys.exit('Updating not implemented yet. '
             'Please update manually with git pull in utils.')

check_call([GIT, 'clone', '-b', BRANCH, REPO, join(stack_dir, 'utils')])
check_call([GIT, 'config', '--file', config_file, '--bool',
        'platform.useDocker', str(use_docker)])
# the target needs to be relative
os.symlink(join('utils', 'Makefile'), join(stack_dir, 'Makefile'))

# TODO check free space and warn?

print("""
Now do

    cd "{!s}"
    $EDITOR utils/config
    $EDITOR utils/configuration.mk
    bash utils/install.sh
    make

""".format(stack_dir)
)
