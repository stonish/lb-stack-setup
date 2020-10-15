#!/usr/bin/env python3
import json
import os
import re
import shutil
import stat
from collections import OrderedDict
from utils import setup_logging

DIR = os.path.dirname(__file__)
TEMPLATE = os.path.join(DIR, 'template.code-workspace')
WORKSPACE = 'stack.code-workspace'
log = None


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


def read_runtime_env(filename):
    with open(filename) as f:
        return dict(tuple(line.rstrip('\n').split('=', 1)) for line in f)


def get_runtime_var(filename, name, default=None):
    try:
        return read_runtime_env(filename)[name]
    except (FileNotFoundError, KeyError):
        return default


def create_clang_format(config, path='.clang-format'):
    from subprocess import check_call
    if not os.path.isfile(path):
        check_call([
            os.path.join(DIR, 'build-env'),
            os.path.join(config['lbenvPath'], 'bin/python'), '-c',
            'from LbDevTools import createClangFormat\n'
            'createClangFormat({!r})'.format(path)
        ])


def create_python_tool_wrappers(config):
    """Create environment agnostic wrappers for LbEnv tools.

    The vscode-python extension executes yapf/flake8 inside the runtime
    environment (defined by python.envFile). For us this is the LCG
    python, which is incompatible with LbEnv. This simply produces
    "env -i" wrappers of the LbEnv executables.

    """
    for name in ['flake8', 'yapf']:
        src = os.path.join(config['lbenvPath'], 'bin', name)
        dst = os.path.join(config['outputPath'], name)
        with open(dst, 'w') as f:
            f.write('#!/bin/sh\n')
            f.write('env -i {} "$@"\n'.format(src))
            os.chmod(f.fileno(), stat.S_IRWXU)


def update_json(filename, update):
    try:
        shutil.move(filename, filename + "~")
        with open(filename + "~") as f:
            data = json.load(f)
    except FileNotFoundError:
        data = {}
    with open(filename, 'w') as f:
        json.dump(update(data), f, indent=4, sort_keys=True)


def dict_update(updates):
    def update(data):
        data = data.copy()
        data.update(updates)
        return data

    return update


def write_workspace_settings(repos,
                             config,
                             template_path=TEMPLATE,
                             output_path=WORKSPACE):
    stack_dir = os.path.dirname(output_path)

    with open(template_path) as f:
        s = f.read()
    s = re.sub(r'^\s*//.*$', '', s, flags=re.MULTILINE)
    template = json.loads(s)
    settings = rinterp(template, dict(config, utilsPath=DIR))

    folder_paths = OrderedDict()  # use that as an "ordered set"
    # first collect stack projects
    for path in repos + [folder['path'] for folder in settings['folders']]:
        path = os.path.relpath(path, stack_dir)
        folder_paths[path] = None  # None is a dummy value
    settings['folders'] = list({'path': p} for p in folder_paths)

    runtime_env_path = os.path.join(config['outputPath'], 'runtime-Gaudi.env')
    path = get_runtime_var(runtime_env_path, 'PATH')
    if not path:
        log.debug(
            'Could not get PATH from {}. '
            'Maybe Gaudi is not yet (fully) built.'.format(runtime_env_path))
        log.warning('Build at least Gaudi for C++/Python intellisense to work')
    else:
        python_cmd = shutil.which('python', path=path)
        if python_cmd:
            settings['settings']['python.pythonPath'] = python_cmd
        else:
            log.debug('Could not find python executable.'
                      'Maybe Gaudi is not yet (fully) built.')

        gcc_cmd = shutil.which('g++', path=path)
        clang_cmd = shutil.which('clang', path=path)
        if gcc_cmd and clang_cmd:
            log.warning('Both g++ and clang in path, using g++.')
        if gcc_cmd:
            settings['settings']['C_Cpp.default.compilerPath'] = gcc_cmd
        elif clang_cmd:
            settings['settings']['C_Cpp.default.compilerPath'] = clang_cmd
        else:
            log.debug('Could not find compiler executable. '
                      'Maybe Gaudi is not yet (fully) built.')

    with open(output_path, 'w') as f:
        f.write("// DO NOT EDIT: this file is auto-generated from {}\n".format(
            template_path))
        json.dump(settings, f, indent=4, sort_keys=True)


def write_project_settings(repos, project_deps, config):
    repos = {os.path.basename(path): path for path in repos}
    # Collect python import paths
    python_paths = {}
    for project, repo_path in repos.items():
        os.makedirs(os.path.join(repo_path, '.vscode'), exist_ok=True)

        runtime_env_path = os.path.join(config['outputPath'],
                                        'runtime-{}.env'.format(project))
        paths = get_runtime_var(runtime_env_path, 'PYTHONPATH')
        if paths:
            paths = paths.split(':')
        else:
            log.debug('Could not get PYTHONPATH from {}. '
                      'Maybe {} is not yet built.'.format(
                          runtime_env_path, repo_path))
            continue

        # filter out generated python (i.e. genConf) from both build and
        # install directories
        veto = re.compile(r'/build.[^/]+/|/InstallArea/')
        python_paths[project] = [p for p in paths if not veto.search(p)]

    missing_runtime = set(repos).difference(python_paths)
    if missing_runtime:
        log.info('Build {} to get full Python intellisense.'.format(
            ', '.join(missing_runtime)))

    # For projects where we couldn't get PYTHONPATH, try some of their deps
    def get_paths(project):
        try:
            return python_paths[project]
        except KeyError:
            log.debug('Using partial PYTHONPATH from dependencies for {}'.
                      format(project))
            paths = sum((get_paths(d) for d in project_deps.get(project, [])),
                        [])
            python_paths[project] = paths
            return paths

    for project, repo_path in repos.items():
        settings_path = os.path.join(repo_path, '.vscode', 'settings.json')
        update_json(
            settings_path,
            dict_update({
                'python.analysis.extraPaths': get_paths(project)
            }))


def write_data_package_settings(repos):
    for path in repos:
        os.makedirs(os.path.join(path, '.vscode'), exist_ok=True)
        settings_path = os.path.join(path, '.vscode', 'settings.json')

        update_json(
            settings_path,
            dict_update({
                # prevent warnings that compile commands are missing
                'C_Cpp.default.compileCommands': ''
            }))


def write_vscode_settings(repos, dp_repos, project_deps, config):
    global log
    log = setup_logging(config['outputPath'])

    write_workspace_settings(repos + dp_repos, config)
    write_project_settings(repos, project_deps, config)
    write_data_package_settings(dp_repos)
    create_clang_format(config)
    create_python_tool_wrappers(config)
