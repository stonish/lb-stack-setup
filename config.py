#!/usr/bin/python
from __future__ import print_function
import errno
import json
import os
from collections import OrderedDict

# Python 3 compatiblity
try:
    basestring
except NameError:
    basestring = str
    unicode = str

DIR = os.path.dirname(__file__)
DEFAULT_CONFIG = os.path.join(DIR, 'default-config.json')
CONFIG = os.path.join(DIR, 'config.json')
# Special variables where paths are expanded
EXPAND_PATH_VARS = ["projectPath", "contribPath", "ccachePath", "outputPath"]


def cpu_count():
    from multiprocessing import cpu_count
    return cpu_count()


def git_base():
    choices = [
        "ssh://git@gitlab.cern.ch:7999",
        "https://:@gitlab.cern.ch:8443",
        "https://gitlab.cern.ch",
    ]
    for base in choices:
        code = os.system(
            'git ls-remote {}/gaudi/Gaudi.git HEAD &>/dev/null'.format(base))
        if code == 0:
            # TODO output logging warnings on stderr
            # if base != choices[0]:
            #     logging.warning('Using {} git base for cloning as {} is not accessible'
            #                     .format(base, choices[0]))
            return base
    # This really should not happen, but let's not crash
    # TODO output logging warnings on stderr
    return ''


AUTOMATIC_DEFAULTS = {
    'gitBase': git_base,
    'localPoolDepth': lambda: 2 * cpu_count(),
    'distccLocalslots': cpu_count,
    'distccLocalslotsCpp': lambda: 2 * cpu_count(),
}


def check_type(key, value, default_value):
    expected_type = type(default_value)
    if default_value is not None and not isinstance(value, expected_type):
        import warnings
        warnings.warn(
            'Got {!r} ({}) for key {!r}, expected {} type.\n'
            'See {} for supported configuration.'.format(
                value,
                type(value).__name__, key, expected_type.__name__,
                DEFAULT_CONFIG),
            stacklevel=2)


def write_config(config, path=CONFIG):
    with open(path, 'w') as f:
        json.dump(config, f, indent=4)


def expand_path(p):
    """Expand and normalise a non-absolute path."""
    p = os.path.expandvars(p)
    p = os.path.expanduser(p)
    if not os.path.isabs(p):
        p = os.path.join(DIR, p)
    return os.path.abspath(p)


def read_config(original=False,
                default_config=DEFAULT_CONFIG,
                config_in=CONFIG,
                config_out=None):
    with open(default_config) as f:
        defaults = json.load(f, object_pairs_hook=OrderedDict)

    overrides = {}
    if config_in:
        try:
            with open(config_in) as f:
                overrides = json.load(f, object_pairs_hook=OrderedDict)
        except IOError as e:
            if e.errno != errno.ENOENT:
                raise

    for key, value in overrides.items():
        try:
            check_type(key, value, defaults[key])
        except KeyError:
            import warnings
            warnings.warn(
                'Unknown key {} found in {}.\n'
                'See {} for supported configuration.'.format(
                    key, config_in, default_config),
                stacklevel=2)

    config = OrderedDict(list(defaults.items()) + list(overrides.items()))

    # Assign automatic defaults
    dirty = False
    for key in config:
        if config[key] is None and key in AUTOMATIC_DEFAULTS:
            dirty = True
            config[key] = overrides[key] = AUTOMATIC_DEFAULTS[key]()

    # Write automatic defaults to user config
    if dirty and config_out:
        write_config(overrides, config_out)

    # Expand variables
    for key in config:
        if key in EXPAND_PATH_VARS:
            config[key] = expand_path(config[key])

    return (config, defaults, overrides) if original else config
    # TODO think if we need nested updates and in any case document behaviour


def format_value(x):
    """Return json except for strings, which are printed unquoted."""
    return x if isinstance(x, basestring) else json.dumps(x)


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('key', nargs='?', help='Configuration key')
    parser.add_argument('value', nargs='?', help='New value to set')
    parser.add_argument(
        '--sh', nargs='+', help='Print values as shell commands')
    args = parser.parse_args()

    if args.key and args.sh:
        parser.error('All keys must be right of --sh')

    config, defaults, overrides = read_config(True, config_out=CONFIG)
    if args.sh:
        for key in args.sh:
            print('{}="{}"'.format(key, format_value(config[key])))
    elif not args.key:
        # print entire config
        print(json.dumps(config, indent=4))
    elif not args.value:
        # print the value for a key
        print(format_value(config[args.key]))
    else:
        # set the value for a key
        if isinstance(defaults[args.key], basestring):
            value = unicode(args.value)
        else:
            try:
                value = json.loads(args.value)
            except ValueError:
                # invalid json is treated as unquoted string
                value = unicode(args.value)
        overrides[args.key] = value
        check_type(args.key, value, defaults[args.key])
        write_config(overrides)
