import logging
import os
import textwrap
import time
from collections import namedtuple
from subprocess import Popen, PIPE, CalledProcessError
try:
    from subprocess import DEVNULL
except ImportError:
    DEVNULL = open(os.devnull, 'r')

_log = None
_log_filename = None


class ConsoleFormatter(logging.Formatter):
    """Colourful logging formatter."""

    def __init__(self):
        default = "\033[1m%(levelname)-8s\033[0m %(message)s"
        yellow = "\x1b[33;21m"
        red = "\x1b[31;21m"
        self._default = logging.Formatter(default)
        self._warning = logging.Formatter(yellow + default)
        self._error = logging.Formatter(red + default)
        self._header_len = 9

    def format(self, record):
        if record.levelno < logging.WARNING:
            formatter = self._default
        elif record.levelno < logging.ERROR:
            formatter = self._warning
        else:
            formatter = self._error
        record.msg = textwrap.indent(record.msg,
                                     ' ' * self._header_len).lstrip()
        return formatter.format(record)


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
    console.setFormatter(ConsoleFormatter())
    logging.getLogger('').addHandler(console)
    _log = logging.getLogger(os.path.basename(__file__))
    return _log


def run_nb(args,
           shell=False,
           capture_stdout=True,
           capture_stderr=True,
           check=True,
           stdin=DEVNULL,
           log=True,
           **kwargs):
    """Non-blocking run() that returns a blocking function."""
    p = Popen(
        args,
        shell=shell,
        stdin=stdin,
        stdout=kwargs.pop('stdout', PIPE if capture_stdout else None),
        stderr=kwargs.pop('stderr', PIPE if capture_stderr else None),
        **kwargs)

    def result():
        cmd_msg = (repr(args) if shell else ' '.join(map(repr, args)))
        cwd = kwargs.get("cwd")
        in_dir_msg = "" if cwd is None else f" (in {cwd})"
        if log:
            _log.debug(f"Running command{in_dir_msg}: {cmd_msg}")
        stdout, stderr = [
            b if b is None else b.decode('utf-8') for b in p.communicate()
        ]
        level = logging.ERROR if check and p.returncode else logging.DEBUG
        if log or level == logging.ERROR:
            msg = (f"Result of command{in_dir_msg}: {cmd_msg}\n" +
                   f"\tretcode: {p.returncode}")
            if stderr is not None:
                msg += "\n\tstderr: " + stderr.rstrip("\n")
            if stdout is not None:
                msg += "\n\tstdout: " + stdout.rstrip("\n")
            _log.log(level, msg)
        if check and p.returncode != 0:
            raise CalledProcessError(p.returncode, args)
        return namedtuple('CompletedProcess',
                          ['returncode', 'stdout', 'stderr'])(p.returncode,
                                                              stdout, stderr)

    return result


def run(args,
        shell=False,
        capture_stdout=True,
        capture_stderr=True,
        check=True,
        stdin=DEVNULL,
        **kwargs):
    return run_nb(args, shell, capture_stdout, capture_stderr, check, stdin,
                  **kwargs)()


def write_file_if_different(path, contents, executable=False, backup=None):
    """Write `contents` to file `path` unless already identical.

    Returns old file contents if file was modified or None otherwise.

    """
    # use a+ instead of r+ so that the file is created if not existing
    with open(path, 'a+') as f:
        f.seek(0)
        old_contents = f.read()
        if callable(contents):
            contents = contents(old_contents)
        mode = new_mode = 0
        if executable:
            mode = os.fstat(f.fileno()).st_mode
            new_mode = mode | ((mode & 0o444) >> 2)  # copy R bits to X
        if contents == old_contents and mode == new_mode:
            return None
        f.seek(0)
        f.truncate()
        f.write(contents)
        if executable:
            os.chmod(f.fileno(), mode)
    if backup is not None:
        with open(backup, 'w') as f:
            f.write(old_contents)
    return old_contents


def topo_sorted(deps, start=None):
    """Toplogically sort dependent projects.

    Returns a sorted list of projects where each element can only depend
    on the preceding ones. If `start` (list) is passed, only the listed
    projects are traversed. Otherwise, all projects are traversed.

    """

    def walk(projects, seen):
        return sum((seen.add(p) or (walk(deps.get(p, []), seen) + [p])
                    for p in sorted(projects) if p not in seen), [])

    return walk(start or deps, set())


def add_file_to_git_exclude(root_dir, filename):
    """Adds `filename` as exclude pattern to `root_dir`/.git/info/exclude

    If `root_dir` doesn't contain a .git folder this function is a silent noop

    """

    if os.path.isdir(os.path.join(root_dir, '.git')):
        os.makedirs(os.path.join(root_dir, '.git', 'info'), exist_ok=True)
        exclude = os.path.join(root_dir, '.git', 'info', 'exclude')
        with open(exclude, 'a+') as f:
            f.seek(0)
            if filename not in f.read().splitlines():
                f.write(filename + '\n')


def _mtime_or_zero(path):
    """Return file mtime or zero if file is not found or is empty."""
    try:
        result = os.stat(path)
        return result.st_mtime if result.st_size > 0 else 0
    except FileNotFoundError:
        return 0


def is_file_older_than_ref(path, reference):
    return _mtime_or_zero(path) < _mtime_or_zero(reference)


def is_file_too_old(path, age):
    return time.time() - _mtime_or_zero(path) > age
