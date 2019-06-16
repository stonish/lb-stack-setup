#!/usr/bin/env python
from __future__ import print_function
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


def check_type(key, value, expected_type):
    if not isinstance(value, expected_type):
        import warnings
        warnings.warn('Got {!r} for key {!r}, expected {} type.\n'
                    'See {} for supported configuration.'
                    .format(value, key, expected_type, DEFAULT_CONFIG),
                    stacklevel=2)

def read_config(original=False):
    with open(DEFAULT_CONFIG) as f:
        defaults = json.load(f, object_pairs_hook=OrderedDict)

    try:
        with open(CONFIG) as f:
            overrides = json.load(f, object_pairs_hook=OrderedDict)
    except IOError as e:
        if e.errno == errno.EEXIST:
            overrides = {}
        else:
            raise

    for key, value in overrides.items():
        try:
            check_type(key, value, type(defaults[key]))
        except KeyError:
            import warnings
            warnings.warn('Key {} not in {}.\nSee {} for supported configuration.'
                        .format(key, CONFIG, DEFAULT_CONFIG), stacklevel=2)

    config = OrderedDict(list(defaults.items()) + list(overrides.items()))
    return (config, defaults, overrides) if original else config
    # TODO think if we need nested updates and in any case document behaviour


if __name__ == '__main__':
    import argparse
    import sys

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
        check_type(args.key, value, type(defaults[args.key]))
        with open(CONFIG, 'w') as f:
            json.dump(overrides, f, indent=4)