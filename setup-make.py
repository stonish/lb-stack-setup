#!/usr/bin/env python3
"""Write project configuration in a makefile."""
from __future__ import print_function
import glob
import itertools
import os
import pathlib
import re
import time
from subprocess import CalledProcessError
import traceback
import sys
from config import read_config, DIR, GITLAB_READONLY_URL, GITLAB_BASE_URLS
from utils import setup_logging, run, run_nb, topo_sorted
from vscode import write_vscode_settings

DATA_PACKAGE_DIRS = ["DBASE", "PARAM"]
MAKE_TARGET_RE = re.compile(
    r'^(?P<fast>fast/)?(?P<project>[A-Z]\w+)(/(?P<target>.*))?$')

config = None
log = None


def data_package_container(name):
    param_packages = [
        "BcVegPyData", "ChargedProtoANNPIDParam", "Geant4Files", "GenXiccData",
        "MCatNLOData", "MIBData", "ParamFiles", "QMTestFiles", "TMVAWeights"
    ]
    return "PARAM" if name in param_packages else "DBASE"


class NotCMakeProjectError(RuntimeError):
    pass


def mkdir_p(path):
    pathlib.Path(path).mkdir(parents=True, exist_ok=True)


def symlink(src, dst):
    """Create a symlink only if not already existing and equivalent."""
    if os.path.realpath(dst) == src:
        return
    if os.path.isfile(dst):
        os.remove(dst)
    os.symlink(src, dst)


def git_url_branch(project, try_read_only=False):
    url = config['gitUrl'].get(project)
    if not url:
        group = config['gitGroup']
        group = group.get(project, group['default'])
        url = '{}/{}/{}.git'.format(config['gitBase'], group, project)
    if try_read_only:
        # Swap out the base for the read-only base
        for base in GITLAB_BASE_URLS:
            if url.startswith(base):
                url = GITLAB_READONLY_URL + url[len(base):]
                break
    branch = config['gitBranch']
    branch = branch.get(project, branch['default'])
    return url, branch


def cmake_name(project):
    with open(os.path.join(project, 'CMakeLists.txt')) as f:
        cmake = f.read()
    m = re.search(
        r'\s+(gaudi_)?project\(\s*(?P<name>\w+)\s', cmake, flags=re.IGNORECASE)
    return m.group('name')


def old_cmake_deps(project):
    cmake_path = os.path.join(project, 'CMakeLists.txt')
    try:
        with open(cmake_path) as f:
            cmake = f.read()
    except IOError:
        raise NotCMakeProjectError('{} is not a CMake project'.format(project))
    m = re.search(r'gaudi_project\(([^\)]+)\)', cmake)
    if not m:
        return []
    args = m.group(1).split()
    try:
        args = args[args.index('USE') + 1:]
    except ValueError:  # USE not in list (Gaudi)
        return []

    # take (name, version) pairs until the next keyword
    # (see gaudi_project in GaudiProjectConfig.cmake)
    KEYWORDS = ['USE', 'DATA', 'TOOLS', 'FORTRAN']
    deps = list(itertools.takewhile(lambda x: x not in KEYWORDS, args))
    if not len(deps) % 2 == 0:
        raise RuntimeError('Bad gaudi_project() call in {}'.format(cmake_path))
    return deps[::2]


def find_project_deps(project):
    """Return the direct dependencies of a project."""
    IGNORED_DEPENDENCIES = ["LCG", "DBASE", "PARAM"]
    metadata_path = os.path.join(project, 'lhcbproject.yml')
    try:
        with open(metadata_path) as f:
            metadata = f.read()
        m = re.search(r'(\n|^)dependencies:\s(?P<deps>(\s+-\s+\w+\n)+)',
                      metadata)
        if not m:
            raise RuntimeError(f'dependencies not found in {metadata_path}')
        deps = [s.strip(' -') for s in m.group('deps').splitlines()]
        deps = [d for d in deps if d not in IGNORED_DEPENDENCIES]
    except IOError:
        # Fall back to old-style cmake
        deps = old_cmake_deps(project)
    return deps + config['extraDependencies'].get(project, [])


def clone_cmake_project(project):
    """Clone project and return canonical name.

    When cloning, if necessary, the directory is renamed to the
    project's canonical name as specified in the CMakeLists.txt.
    Nothing is done if the project directory already exists.

    """
    m = [x for x in os.listdir('.') if x.lower() == project.lower()]
    assert len(m) <= 1, 'Multiple directories for project: ' + str(m)
    if not m:
        url, branch = git_url_branch(project)
        run(['git', 'clone', url, project])
        run(['git', 'checkout', branch], cwd=project)
        run(['git', 'submodule', 'update', '--init', '--recursive'],
            cwd=project)
    else:
        project = m[0]
    canonical_name = cmake_name(project)
    if canonical_name != project:
        if not m:
            os.rename(project, canonical_name)
            project = canonical_name
        else:
            raise RuntimeError('Project {} already cloned under '
                               'non-canonical name {}'.format(
                                   canonical_name, project))
    return project


def clone_package(name, path):
    # TODO remove warning in one year (November 2021)
    if path != 'DBASE' and os.path.isdir(os.path.join('DBASE', name)):
        log.warning(
            'Please move package {} from {} to {} and `make purge`'.format(
                name, 'DBASE', path))

    full_path = os.path.join(path, name)
    if not os.path.isdir(full_path):
        run([
            os.path.join(DIR, 'build-env'),
            os.path.join(config['lbenvPath'], 'bin/git-lb-clone-pkg'), name
        ],
            stdout=None,
            stderr=None,
            stdin=None,
            cwd=path)
    return full_path


def list_repos(path=''):
    """Return all git repositories under the directory path."""
    paths = [p[:-5] for p in glob.glob(os.path.join(path, '*/.git'))]
    return sorted(p for p in paths if os.path.abspath(p) != DIR)


def _mtime_or_zero(path):
    try:
        result = os.stat(path)
        return result.st_mtime if result.st_size > 0 else 0
    except FileNotFoundError:
        return 0


def check_staleness(repos):
    FETCH_TTL = 3600  # seconds
    to_fetch = [
        p for p in repos if time.time() -
        _mtime_or_zero(os.path.join(p, '.git', 'FETCH_HEAD')) > FETCH_TTL
    ]
    if to_fetch:
        log.info("Fetching {}".format(', '.join(to_fetch)))
        ps = []
        for p in to_fetch:
            url, branch = git_url_branch(p, try_read_only=True)
            ps.append(
                # TODO: fetch origin if its URL matches the config's URL,
                # otherwise, fetch the URL directly:
                # run_nb(['git', 'fetch', url, branch], cwd=p, check=False))
                # NOT WORKING because DPs trying to
                # 'git' 'fetch' 'https://gitlab.cern.ch/lhcb/DBASE/AppConfig.git' 'master'
                run_nb(['git', 'fetch', 'origin', branch], cwd=p, check=False))
            #  +refs/merge-requests/*/head:refs/remotes/origin/mr/*
        # wait for all fetching to finish
        rcs = [result().returncode for result in ps]
        failed = [p for p, rc in zip(to_fetch, rcs) if rc != 0]
        if failed:
            log.warning("Failed to fetch " + ", ".join(failed))

    targets = ['origin/' + git_url_branch(p)[1] for p in repos]
    diff_cmd = ['git', 'rev-list', '--count', '--left-right', 'FETCH_HEAD...']
    ps = [run_nb(diff_cmd, cwd=p, check=False) for p in repos]
    for path, target, result in zip(repos, targets, ps):
        try:
            res = result()
            n_behind, n_ahead = map(int, res.stdout.split())
            if n_behind:
                ref_names = run(['git', 'log', '-n1', '--pretty=%D'],
                                cwd=path).stdout.strip()
                if not n_ahead:
                    log.warning('{} ({}) is {} commits behind {}'.format(
                        path, ref_names, n_behind, target))
                else:
                    log.warning(
                        '{} ({}) is {} commits behind ({} ahead) {}'.format(
                            path, ref_names, n_behind, n_ahead, target))
            elif n_ahead:
                log.info('{} is {} commits ahead {}'.format(
                    path, n_ahead, target))
        except (CalledProcessError, ValueError):
            log.warning('Failed to get status of ' + path)


def checkout(projects, data_packages):
    """Clone projects and data packages, and return make configuration.

    The project dependencies of `projects` are cloned recursively.

    """
    project_deps = {}
    to_checkout = list(projects)
    while to_checkout:
        p = to_checkout.pop(0)
        p = clone_cmake_project(p)
        deps = find_project_deps(p)
        to_checkout.extend(sorted(set(deps).difference(project_deps)))
        project_deps[p] = deps

    # Check that all dependencies are also keys
    assert set().union(*project_deps.values()).issubset(project_deps)

    dp_repos = []
    for name in data_packages:
        container = data_package_container(name)
        mkdir_p(container)
        dp_repos.append(clone_package(name, container))

    check_staleness(list(project_deps.keys()) + dp_repos)

    return project_deps


def find_all_deps(repos, project_deps={}):
    project_deps = project_deps.copy()
    for r in repos:
        if r not in project_deps:
            try:
                project_deps[r] = find_project_deps(r)
            except NotCMakeProjectError:
                pass
    return project_deps


def inv_dependencies(project_deps):
    return {
        d: set(p for p, deps in project_deps.items() if d in deps)
        for d in project_deps
    }


def main(targets):
    global config, log
    config = read_config()
    log = setup_logging(config['outputPath'])

    # save the host environment where we're executed
    output_path = config['outputPath']
    mkdir_p(output_path)
    with open(os.path.join(output_path, 'host.env'), 'w') as f:
        for name, value in sorted(os.environ.items()):
            print(name + "=" + value, file=f)

    # collect top level projects to be cloned
    projects = []
    fast_checkout_projects = []
    for arg in targets:
        m = MAKE_TARGET_RE.match(arg)
        if m:
            if m.group('fast') and m.group('target') == 'checkout':
                fast_checkout_projects.append(m.group('project'))
            else:
                projects.append(m.group('project'))
    if 'build' in targets or 'all' in targets or not targets:
        build_target_deps = config['defaultProjects']
        projects += build_target_deps
    else:
        build_target_deps = []

    # Install symlinks to external software such that CMake doesn't cache them
    LBENV_BINARIES = ['cmake', 'ctest', 'ninja', 'ccache']
    mkdir_p(os.path.join(config['contribPath'], 'bin'))
    for fn in LBENV_BINARIES:
        symlink(
            os.path.join(config['lbenvPath'], 'bin', fn),
            os.path.join(config['contribPath'], 'bin', fn))

    try:
        # Clone projects without following their dependencies and without
        # making any real target, e.g. `make fast/Moore/checkout`.
        for p in fast_checkout_projects:
            clone_cmake_project(p)

        # Clone data packages and projects to build with dependencies.
        data_packages = config['dataPackages']
        project_deps = checkout(projects, data_packages)

        # After we cloned the minimum necessary, check for other repos
        repos = list_repos()
        dp_repos = sum((list_repos(d) for d in DATA_PACKAGE_DIRS), [])

        # Find cloned projects that we won't build but that may be
        # dependent on those to build.
        project_deps = find_all_deps(repos, project_deps)

        # Order repos according to dependencies
        project_order = topo_sorted(project_deps) + repos
        repos.sort(key=lambda x: project_order.index(x))

        makefile_config = [
            "BINARY_TAG := {}".format(config["binaryTag"]),
            "PROJECTS := " + " ".join(sorted(project_deps)),
            "DATA_PACKAGES := " + " ".join(sorted(data_packages)),
        ]
        for p, deps in sorted(project_deps.items()):
            makefile_config += [
                "{}_DEPS := {}".format(p, ' '.join(deps)),
            ]
        for p, deps in sorted(inv_dependencies(project_deps).items()):
            makefile_config += [
                "{}_INV_DEPS := {}".format(p, ' '.join(deps)),
            ]
        makefile_config += [
            "CONTRIB_PATH := " + config["contribPath"],
            "REPOS := " + " ".join(repos + dp_repos),
            "build: " + " ".join(build_target_deps),
        ]

    except Exception:
        traceback.print_exc()
        makefile_config = ['$(error Error occurred in checkout)']
    else:
        try:
            write_vscode_settings(repos, dp_repos, project_deps, config)
        except Exception:
            traceback.print_exc()
            makefile_config = [
                '$(warning Error occurred in updating VSCode settings)'
            ]

    config_path = os.path.join(output_path, "configuration.mk")
    with open(config_path, "w") as f:
        f.write('\n'.join(makefile_config) + '\n')
    # Print path so that the generated file can be included in one go
    print(config_path)


if __name__ == '__main__':
    main(sys.argv[1:])
