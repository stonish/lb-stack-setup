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


DIR = os.path.dirname(__file__)
DEFAULT_CONFIG = os.path.join(DIR, 'default-config.json')
CONFIG = os.path.join(DIR, 'config.json')


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
        code = os.system('git ls-remote {}/gaudi/Gaudi.git HEAD &>/dev/null'
                         .format(base))
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
    'localPoolDepth': lambda: 2*cpu_count(),
    'distccLocalslots': cpu_count,
    'distccLocalslotsCpp': lambda: 2*cpu_count(),
}


def check_type(key, value, default_value):
    expected_type = type(default_value)
    if default_value is not None and not isinstance(value, expected_type):
        import warnings
        warnings.warn(
            'Got {!r} ({}) for key {!r}, expected {} type.\n'
            'See {} for supported configuration.'
            .format(value, type(value).__name__, key,
                    expected_type.__name__, DEFAULT_CONFIG),
            stacklevel=2)


def write_config(config, path=CONFIG):
    with open(path, 'w') as f:
        json.dump(config, f, indent=4)


def read_config(original=False, default_config=DEFAULT_CONFIG,
                config_in=CONFIG, config_out=None):
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
            warnings.warn('Unknown key {} found in {}.\n'
                          'See {} for supported configuration.'
                          .format(key, config_in, default_config), stacklevel=2)

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

    # Expand non-absolute *Path variables
    for key in config:
        if key.endswith('Path'):
            p = config[key]
            p = os.path.expandvars(p)
            p = os.path.expanduser(p)
            if not os.path.isabs(p):
                p = os.path.join(DIR, p)
            p = os.path.abspath(p)
            config[key] = p

    return (config, defaults, overrides) if original else config
    # TODO think if we need nested updates and in any case document behaviour


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('key', nargs='?', help='Configuration key')
    parser.add_argument('value', nargs='?', help='New value to set')
    args = parser.parse_args()

    config, defaults, overrides = read_config(True, config_out=CONFIG)
    if not args.key:
        # print entire config
        print(json.dumps(config, indent=4))
    elif not args.value:
        # print the value for a key
        x = config[args.key]
        # write json except for strings, which are printed unquoted
        print(x if isinstance(x, basestring) else json.dumps(x))
    else:
        # set the value for a key
        try:
            value = json.loads(args.value)
        except ValueError:
            # invalid json is treated as unquoted string
            try:
                value = unicode(args.value)
            except NameError:
                value = args.value  # compatiblity with Python 3
        overrides[args.key] = value
        check_type(args.key, value, defaults[args.key])
        write_config(overrides)
