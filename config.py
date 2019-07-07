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


AUTOMATIC_DEFAULTS = {
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


def write_config(config):
    with open(CONFIG, 'w') as f:
        json.dump(config, f, indent=4)


def read_config(original=False):
    with open(DEFAULT_CONFIG) as f:
        defaults = json.load(f, object_pairs_hook=OrderedDict)

    try:
        with open(CONFIG) as f:
            overrides = json.load(f, object_pairs_hook=OrderedDict)
    except IOError as e:
        if e.errno == errno.ENOENT:
            overrides = {}
        else:
            raise

    for key, value in overrides.items():
        try:
            check_type(key, value, defaults[key])
        except KeyError:
            import warnings
            warnings.warn('Unknown key {} found in {}.\n'
                          'See {} for supported configuration.'
                          .format(key, CONFIG, DEFAULT_CONFIG), stacklevel=2)

    config = OrderedDict(list(defaults.items()) + list(overrides.items()))

    # Assign automatic defaults
    dirty = False
    for key in config:
        if config[key] is None and key in AUTOMATIC_DEFAULTS:
            dirty = True
            config[key] = overrides[key] = AUTOMATIC_DEFAULTS[key]()

    # Write automatic defaults to user config
    if dirty:
        write_config(overrides)

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

    config, defaults, overrides = read_config(True)
    if not args.key:
        print(json.dumps(config, indent=4))
    elif not args.value:
        x = config[args.key]
        # write json except for strings, which are printed unquoted
        print(x if isinstance(x, basestring) else json.dumps(x))
    else:
        try:
            value = json.loads(args.value)
        except ValueError:
            value = args.value
        overrides[args.key] = value
        check_type(args.key, value, defaults[args.key])
        write_config(overrides)
