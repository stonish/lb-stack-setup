import logging
import os
from collections import namedtuple
from subprocess import Popen, PIPE, CalledProcessError
try:
    from subprocess import DEVNULL
except ImportError:
    DEVNULL = open(os.devnull, 'r')

log = None


def setup_logging(directory):
    if not os.path.isdir(directory):
        os.mkdir(directory)
    logging.basicConfig(
        level=logging.DEBUG,
        format=
        '%(asctime)s.%(msecs)03d %(name)-15s %(levelname)-8s %(message)s',
        datefmt='%Y-%m-%dT%H:%M:%S',
        filename=os.path.join(directory, 'log'),
        filemode='a')
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter('%(levelname)-8s %(message)s'))
    logging.getLogger('').addHandler(console)
    global log
    log = logging.getLogger(os.path.basename(__file__))
    return log


def run(args,
        shell=False,
        capture_stdout=True,
        capture_stderr=True,
        check=True,
        stdin=DEVNULL,
        **kwargs):
    log.debug('command: ' +
              (repr(args) if shell else ' '.join(map(repr, args))))
    p = Popen(
        args,
        shell=shell,
        stdin=stdin,
        stdout=kwargs.pop('stdout', PIPE if capture_stdout else None),
        stderr=kwargs.pop('stderr', PIPE if capture_stderr else None),
        **kwargs)
    stdout, stderr = p.communicate()
    level = logging.ERROR if check and p.returncode else logging.DEBUG
    log.log(level, 'retcode: ' + str(p.returncode))
    log.log(level, 'stderr: ' + str(stderr))
    log.log(level, 'stdout: ' + str(stdout))
    if check and p.returncode != 0:
        raise CalledProcessError(p.returncode, args)
    return namedtuple('CompletedProcess', ['returncode', 'stdout', 'stderr'])(
        p.returncode, stdout, stderr)
