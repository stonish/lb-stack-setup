#!/usr/bin/env python3
import argparse
import json
import os
import re
import shutil
from collections import OrderedDict
from itertools import chain

DIR = os.path.dirname(__file__)
TEMPLATE = os.path.join(DIR, 'template.code-workspace')
WORKSPACE = 'stack.code-workspace'


def rinterp(obj, mapping):
    """Recursively interpolate object with a dict of values."""

    class Default(dict):
        """{xyz} is not replaced when xyz is not in dict."""

        def __missing__(self, key):
            return "{" + key + "}"

    return _rinterp(obj, Default(mapping))


def _rinterp(obj, mapping):
    try:
        return {k: _rinterp(v, mapping) for k, v in obj.items()}
    except AttributeError:
        pass
    try:
        return obj.format_map(mapping)
    except AttributeError:
        pass
    try:
        return [_rinterp(v, mapping) for v in obj]
    except TypeError:
        return obj


def read_env(filename):
    with open(filename) as f:
        return dict(tuple(line.rstrip('\n').split('=', 1)) for line in f)


def write_workspace_json(repos,
                         config,
                         template_path=TEMPLATE,
                         output_path=WORKSPACE):
    stack_dir = os.path.dirname(output_path)

    with open(template_path) as f:
        s = f.read()
    s = re.sub(r'^\s*//.*$', '', s, flags=re.MULTILINE)
    template = json.loads(s)
    settings = rinterp(template, config)

    folder_paths = OrderedDict()  # use that as an "ordered set"
    # first collect stack projects
    for path in repos + [f['path'] for f in settings['folders']]:
        path = os.path.relpath(path, stack_dir)
        folder_paths[path] = None  # None is a dummy value
    settings['folders'] = list({'path': p} for p in folder_paths)

    # Runtime settings
    try:
        env = read_env('Gaudi/build.{}/python.env'.format(config['binaryTag']))
        python_cmd = shutil.which('python', path=env['PATH'])
        if not python_cmd:
            raise OSError()
        settings['settings']['python.pythonPath'] = python_cmd

        gcc_cmd = shutil.which('g++', path=env['PATH'])
        clang_cmd = shutil.which('clang', path=env['PATH'])
        if gcc_cmd and clang_cmd:
            print('WARNING both g++ and clang in path, using g++')
        if gcc_cmd:
            settings['settings']['C_Cpp.default.compilerPath'] = gcc_cmd
        elif clang_cmd:
            settings['settings']['C_Cpp.default.compilerPath'] = clang_cmd
        else:
            raise OSError()
    except OSError:
        print(
            'WARNING build at least Gaudi for cpp/python intellisense to work')

    output = json.dumps(settings, indent=4, sort_keys=True)
    # strip trailing whitespace
    output = '\n'.join(line.rstrip() for line in output.splitlines())
    with open(output_path, 'w') as f:
        f.write(output)
