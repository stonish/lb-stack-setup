#!/usr/bin/env python3
from __future__ import print_function
import errno
import json
import logging
import os
import re
from collections import OrderedDict
from copy import copy, deepcopy
from string import Template

DIR = os.path.dirname(__file__)
DEFAULT_CONFIG = os.path.join(DIR, 'default-config.json')
CONFIG = os.path.join(DIR, 'config.json')
# Special variables where paths are expanded
EXPAND_PATH_VARS = [
    "projectPath",
    "contribPath",
    "ccachePath",
    "outputPath",
    "buildPath",
]
GITLAB_READONLY_URL = "https://gitlab.cern.ch"
GITLAB_BASE_URLS = [
    "ssh://git@gitlab.cern.ch:7999",
    "https://:@gitlab.cern.ch:8443",
    GITLAB_READONLY_URL,
]


def cpu_count(config=None):
    from multiprocessing import cpu_count
    return cpu_count()


def rinterp(obj, mapping):
    """Recursively interpolate object with a dict of values."""
    return _rinterp(obj, mapping)


def _rinterp(obj, mapping):
    try:
        return {k: _rinterp(v, mapping) for k, v in obj.items()}
    except AttributeError:
        pass
    try:
        return Template(obj).safe_substitute(mapping)
    except TypeError:
        pass
    try:
        return [_rinterp(v, mapping) for v in obj]
    except TypeError:
        return obj


def get_host_os():
    from subprocess import check_output
    host_os = (check_output('/cvmfs/lhcb.cern.ch/lib/bin/host_os').decode(
        'ascii').strip())
    # known compatibilities
    # TODO remove once host_os is updated
    arch, _os = host_os.split("-")
    el9s = ["rhel9", "almalinux9", "centos9", "rocky9"]
    if any(_os.startswith(x) for x in el9s):
        return arch + "-el9"
    return host_os


def slot_config(name):
    fn = f"/cvmfs/lhcbdev.cern.ch/nightlies/{name}/latest/slot-config.json"
    try:
        with open(fn) as f:
            config = json.load(f)
    except FileNotFoundError:
        return
    res = {"gitBranch": {}}
    for p in config["projects"]:
        name = p["name"]
        if name == "LCG":
            res["lcgVersion"] = p["version"]
        elif name not in ["DBASE", "PARAM"]:
            branch = p["version"] if p["version"] != "HEAD" else "master"
            res["gitBranch"][name] = branch
    for p in config["packages"]:
        branch = p["version"] if p["version"].upper() != "HEAD" else "master"
        res["gitBranch"][p["name"]] = branch
    return res


def model_slot(config):
    import sys

    if not (sys.stdin.isatty() and sys.stderr.isatty()):
        return {}

    while True:
        print(
            "Which slot are you targeting (e.g. lhcb-2024-patches lhcb-master ...): ",
            end="",
            file=sys.stderr)
        slot = input()
        if slot == "NA":
            return {"promptedModelSlot": "true"}
        res = slot_config(slot)
        if res: break
        print(
            f"'{slot}' is not an existing slot, try again. " +
            "Use 'NA' to skip and use defaults (master)",
            file=sys.stderr)
    update = {
        "promptedModelSlot": "true",
        "gitBranch": config["gitBranch"],
    }
    for p, v in res["gitBranch"].items():
        if p not in update["gitBranch"]:
            update["gitBranch"][p] = v
        elif update["gitBranch"][p] != v:
            print(
                f"WARNING gitBranch.{p} is already set to " +
                f"{update['gitBranch'][p]} which does not match {v} " +
                f"from {slot}",
                file=sys.stderr)
    return update


def binary_tag(config):
    host_os = get_host_os()
    for pattern, tag in config["defaultBinaryTags"]:
        if re.match(pattern, host_os):
            return {"binaryTag": tag}
    raise RuntimeError("Could not determine default binary tag")


def lcg_version(config):
    host_os = get_host_os()
    for pattern, version in config["defaultLcgVersions"]:
        if re.match(pattern, host_os):
            return {"lcgVersion": version}
    raise RuntimeError("Could not determine default LCG version")


def git_base(config):
    for base in GITLAB_BASE_URLS:
        code = os.system(
            'git ls-remote {}/gaudi/Gaudi.git HEAD &>/dev/null'.format(base))
        if code == 0:
            # TODO output logging warnings on stderr
            # if base != GITLAB_BASE_URLS[0]:
            #     logging.warning('Using {} git base for cloning as {} is not accessible'
            #                     .format(base, GITLAB_BASE_URLS[0]))
            return {"gitBase": base}
    # This really should not happen, but let's not crash
    # TODO output logging warnings on stderr
    return {"gitBase": ""}


def ccache_hosts_key(config):
    """Return the longest matching ccacheHostsPresets key."""
    from socket import getfqdn
    fqdn = getfqdn()
    for key in sorted(config["ccacheHostsPresets"], key=len, reverse=True):
        if fqdn.endswith(key):
            return {"ccacheHostsKey": key}
    return {"ccacheHostsKey": "NA"}


def use_distcc(config):
    if cpu_count() >= 24:
        # Disable distcc if we have many cores
        return {"useDistcc": False}
    if not re.match(r'x86_64[^-]*-centos7-.*', config["binaryTag"]):
        logging.warning(
            "Will disable distcc as it's only supported for CentOS 7")
        return {"useDistcc": False}
    return {"useDistcc": True}


def functor_jit_n_jobs(_):
    return {
        "functorJitNJobs": 4 if cpu_count() >= 8 else max(1,
                                                          cpu_count() // 2)
    }


AUTOMATIC_DEFAULTS = {
    'promptedModelSlot': model_slot,
    'binaryTag': binary_tag,
    'lcgVersion': lcg_version,
    'gitBase': git_base,
    'localPoolDepth': lambda _: {'localPoolDepth': 2 * cpu_count()},
    'distccLocalslots': lambda _: {'distccLocalslots': cpu_count()},
    'distccLocalslotsCpp': lambda _: {'distccLocalslotsCpp': 2 * cpu_count()},
    'useDistcc': use_distcc,
    'ccacheHostsKey': ccache_hosts_key,
    'functorJitNJobs': functor_jit_n_jobs,
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


def normalize_path(p):
    """Normalise a non-absolute path."""
    if not os.path.isabs(p):
        p = os.path.join(DIR, p)
    return os.path.abspath(p)


def recursive_update(obj, updates):
    for key, update in updates.items():
        if key in obj and isinstance(obj[key], dict):
            recursive_update(obj[key], update)
        else:
            obj[key] = update


def _read_json_config(path):
    with open(path) as f:
        data = json.load(f, object_pairs_hook=OrderedDict)
    # filter out "comments" (keys starting with "_")
    data = {k: v for k, v in data.items() if not k.startswith("_")}
    return data


def read_config(original=False,
                default_config=DEFAULT_CONFIG,
                config_in=CONFIG,
                config_out=CONFIG):
    defaults = _read_json_config(default_config)

    overrides = {}
    if config_in:
        try:
            overrides = _read_json_config(config_in)
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

    config = deepcopy(defaults)
    recursive_update(config, overrides)

    # Assign automatic defaults
    dirty = False
    for key in config:
        if config[key] is None and key in AUTOMATIC_DEFAULTS:
            dirty = True
            update = AUTOMATIC_DEFAULTS[key](config)
            import sys
            print(
                "Updating config.json:\n" + json.dumps(update, indent=4),
                file=sys.stderr)
            config.update(update)
            overrides.update(update)

    # Write automatic defaults to user config
    if dirty and config_out:
        write_config(overrides, config_out)

    # Expand variables
    for key, value in config.items():
        # TODO expand recursively?
        if isinstance(value, str):
            value = os.path.expandvars(value)
        if key in EXPAND_PATH_VARS:
            value = os.path.expanduser(value)
            value = normalize_path(value)
        config[key] = value

    # Interpolate self-references like "$projectPath/some/path"
    config = rinterp(config, config)
    for var in EXPAND_PATH_VARS:
        config[var] = normalize_path(config[var])

    return (config, defaults, overrides) if original else config


def query(config, path):
    index = path[0]
    index = int(index) if isinstance(config, list) else str(index)
    subconfig = config[index]
    if len(path) > 1:
        return query(subconfig, path[1:])
    else:
        return subconfig


def query_update(config, path, value):
    index = path[0]
    index = int(index) if isinstance(config, list) else str(index)
    config = copy(config)
    if len(path) > 1:
        config[index] = query_update(config[index], path[1:], value)
    else:
        config[index] = value
    return config


def format_value(x, shell=False):
    """Return json except for strings, which are printed unquoted.

    When shell=True, strings are quoted, list of strings are returned as
    arrays and any other types are not supported.

    """
    if isinstance(x, bool):
        return 'true' if x else 'false'
    if isinstance(x, (int, float)):
        return str(x)
    if isinstance(x, str):
        return ("'" + x + "'") if shell else x
    elif shell and isinstance(x, list) and all(isinstance(i, str) for i in x):
        s = " ".join(("'" + i + "'") for i in x)
        return '(' + s + ')'
    else:
        return json.dumps(x) if not shell else "'NOT-SUPPORTED'"


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument('key', nargs='?', help='Configuration key')
    parser.add_argument('value', nargs='?', help='New value to set')
    parser.add_argument('--default', help='Value to return if key not found')
    parser.add_argument(
        '--sh', nargs='+', help='Print values as shell commands')
    args = parser.parse_args()

    if args.default and (args.value or args.sh):
        parser.error('Cannot use --default with --sh or when setting a new '
                     'value')

    if args.key and args.sh:
        parser.error('All keys must be right of --sh')

    if args.key:
        key_parts = args.key.split('.')

    config, defaults, overrides = read_config(True, config_out=CONFIG)
    if args.sh:
        for key_expr in args.sh:
            if "=" not in key_expr:
                key, value = key_expr, query(config, key_expr.split("."))
            else:
                key, expr = key_expr.split("=", 1)
                value = eval(expr, config)
            print("{}={}".format(key, format_value(value, shell=True)))
    elif not args.key:
        # print entire config
        print(json.dumps(config, indent=4))
    elif args.value is None:
        # print the value for a key
        try:
            value = query(config, key_parts)
        except (IndexError, KeyError):
            if args.default is None:
                raise
            value = args.default
        print(format_value(value))
    else:
        # set the value for a key
        try:
            default_value = query(defaults, key_parts)
        except (IndexError, KeyError):
            # Guess the type as we don't have a schema...
            default_value = ''
        if isinstance(default_value, str):
            value = args.value
        else:
            try:
                value = json.loads(args.value)
            except ValueError:
                # invalid json is treated as unquoted string
                value = args.value

        top_key = key_parts[0]
        if top_key not in overrides and isinstance(config[top_key], dict):
            overrides[top_key] = {}
        overrides[top_key] = query_update(overrides, key_parts, value)[top_key]
        check_type(args.key, value, default_value)
        write_config(overrides)
