import logging
import os
from collections import namedtuple
from subprocess import Popen, PIPE, CalledProcessError
try:
    from subprocess import DEVNULL
except ImportError:
    DEVNULL = open(os.devnull, 'r')

_log = None
_log_filename = None


def setup_logging(directory):
    global _log, _log_filename
    log_filename = os.path.join(directory, 'log')
    if _log is not None:
        if log_filename != _log_filename:
            raise ValueError('requested log to {} but already have {}'.format(
                log_filename, _log_filename))
        return _log
    _log_filename = log_filename
    os.makedirs(directory, exist_ok=True)

    logging.basicConfig(
        level=logging.DEBUG,
        format=
        '%(asctime)s.%(msecs)03d %(name)-15s %(levelname)-8s %(message)s',
        datefmt='%Y-%m-%dT%H:%M:%S',
        filename=log_filename,
        filemode='a')
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter('%(levelname)-8s %(message)s'))
    logging.getLogger('').addHandler(console)
    _log = logging.getLogger(os.path.basename(__file__))
    return _log


def run(args,
        shell=False,
        capture_stdout=True,
        capture_stderr=True,
        check=True,
        stdin=DEVNULL,
        **kwargs):
    _log.debug('command: ' +
               (repr(args) if shell else ' '.join(map(repr, args))))
    p = Popen(
        args,
        shell=shell,
        stdin=stdin,
        stdout=kwargs.pop('stdout', PIPE if capture_stdout else None),
        stderr=kwargs.pop('stderr', PIPE if capture_stderr else None),
        **kwargs)
    stdout, stderr = [
        b if b is None else b.decode('utf-8') for b in p.communicate()
    ]
    level = logging.ERROR if check and p.returncode else logging.DEBUG
    _log.log(level, 'retcode: ' + str(p.returncode))
    _log.log(level, 'stderr: {}'.format(stderr))
    _log.log(level, 'stdout: {}'.format(stdout))
    if check and p.returncode != 0:
        raise CalledProcessError(p.returncode, args)
    return namedtuple('CompletedProcess', ['returncode', 'stdout', 'stderr'])(
        p.returncode, stdout, stderr)


def write_file_if_different(path, contents, mode=None):
    """Write `contents` to file `path` unless already identical.

    Returns old file contents if file was modified or None otherwise.

    """
    # use a+ instead of r+ so that the file is created if not existing
    with open(path, 'a+') as f:
        f.seek(0)
        old_contents = f.read()
        if contents == old_contents:
            return None
        f.seek(0)
        f.truncate()
        f.write(contents)
        if mode is not None:
            os.chmod(f.fileno(), mode)
    return old_contents
