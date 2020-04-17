#!/usr/bin/python
"""Write project configuration in a makefile."""
from __future__ import print_function
import glob
import itertools
import os
import re
import traceback
import sys
from config import read_config, DIR

DATA_PACKAGE_DIR = "DBASE"

config = read_config()


class NotGaudiProjectError(RuntimeError):
    pass


try:
    # Python >= 3.5
    import pathlib

    def mkdir_p(path):
        pathlib.Path(path).mkdir(parents=True, exist_ok=True)
except ImportError:

    def mkdir_p(path):
        try:
            os.makedirs(path)
        except OSError as exc:
            import errno
            if exc.errno == errno.EEXIST and os.path.isdir(path):
                pass
            else:
                raise


def git_url_branch(project):
    group = config['gitGroup']
    branch = config['gitBranch']
    return ('{}/{}/{}.git'.format(config['gitBase'],
                                  group.get(project, group['default']),
                                  project),
            branch.get(project, branch['default']))


def cmake_name(project):
    with open(os.path.join(project, 'CMakeLists.txt')) as f:
        cmake = f.read()
    m = re.search(r'gaudi_project\(\s*(\w+)\s', cmake)
    return m.group(1)


def cmake_deps(project):
    cmake_path = os.path.join(project, 'CMakeLists.txt')
    try:
        with open(cmake_path) as f:
            cmake = f.read()
    except IOError:
        raise NotGaudiProjectError('{} is not a Gaudi project'.format(project))
    m = re.search(r'gaudi_project\(([^\)]+)\)', cmake)
    if not m:
        raise NotGaudiProjectError('{} is not a Gaudi project'.format(project))
    args = m.group(1).split()
    try:
        args = args[args.index('USE') + 1:]
    except ValueError:  # USE not in list (Gaudi)
        return []

    # take (name, version) pairs until the next keyword
    # (see gaudi_project in GaudiProjectConfig.cmake)
    KEYWORDS = ['USE', 'DATA', 'TOOLS', 'FORTRAN']
    deps = list(itertools.takewhile(lambda x: not x in KEYWORDS, args))
    if not len(deps) % 2 == 0:
        raise RuntimeError('Bad gaudi_project() call in {}'.format(cmake_path))
    return deps[::2]


def clone(project):
    """Clone project and return canonical name."""
    m = [x for x in os.listdir('.') if x.lower() == project.lower()]
    assert len(m) <= 1, 'Multiple directories for project: ' + str(m)
    if not m:
        url, branch = git_url_branch(project)
        from subprocess import check_output
        check_output(['git', 'clone', url])
        check_output(['git', 'checkout', branch], cwd=project)
        check_output(['git', 'submodule', 'update', '--init', '--recursive'],
                     cwd=project)
        # TODO send output to stderr or log
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
    if not os.path.isdir(os.path.join(path, name)):
        from subprocess import check_output
        # TODO fix hardcoded LbEnv version
        check_output(
            [os.path.join(config['lbenvPath'], 'bin/git-lb-clone-pkg'), name],
            cwd=path)
        # TODO send output to stderr or log


def list_repos(path=''):
    """Return all git repositories under the directory path."""
    paths = [p[:-5] for p in glob.glob(os.path.join(path, '*/.git'))]
    return [p for p in paths if os.path.abspath(p) != DIR]


def checkout(projects, data_packages):
    """Clone projects and data packagas, and return make configuration.

    The project dependencies of `projects` are cloned recursively.

    """
    project_deps = {}
    to_checkout = list(projects)
    while to_checkout:
        p = to_checkout.pop(0)
        if not os.path.isdir(p):
            p = clone(p)
        deps = cmake_deps(p)
        to_checkout.extend(sorted(set(deps).difference(project_deps)))
        project_deps[p] = deps

    assert set().union(*project_deps.values()).issubset(project_deps)

    # Find projects that we wont build but may be dependent on those to build
    for r in list_repos(''):
        if r not in project_deps:
            try:
                project_deps[r] = cmake_deps(r)
            except NotGaudiProjectError:
                pass

    inv_dependencies = {
        d: set(p for p, deps in project_deps.items() if d in deps)
        for d in project_deps
    }

    mkdir_p(DATA_PACKAGE_DIR)
    for name in data_packages:
        clone_package(name, DATA_PACKAGE_DIR)

    makefile_config = [
        "PROJECTS := " + " ".join(sorted(project_deps)),
        "DATA_PACKAGES := " + " ".join(sorted(data_packages)),
    ]
    for p, deps in sorted(project_deps.items()):
        makefile_config += [
            "{}_DEPS := {}".format(p, ' '.join(deps)),
        ]
    for p, deps in sorted(inv_dependencies.items()):
        makefile_config += [
            "{}_INV_DEPS := {}".format(p, ' '.join(deps)),
        ]
    return makefile_config


def main(targets):
    # save the host environment where we're executed
    output_path = config['outputPath']
    mkdir_p(output_path)
    with open(os.path.join(output_path, 'host.env'), 'w') as f:
        for name, value in sorted(os.environ.items()):
            print(name + "=" + value, file=f)

    # collect top level projects to be cloned
    projects = []
    for arg in targets:
        m = re.match(r'^(fast/)?(?P<project>[A-Z]\w+)(/.+)?$', arg)
        if m:
            projects.append(m.group('project'))
    if 'build' in targets or 'all' in targets or not targets:
        projects += config['defaultProjects']

    try:
        makefile_config = checkout(projects, config['dataPackages'])
        makefile_config += [
            "CONTRIB_PATH := " + config["contribPath"],
            "REPOS := " +
            " ".join(list_repos() + list_repos(DATA_PACKAGE_DIR)),
            "build: " + " ".join(config['defaultProjects']),
        ]
    except Exception as e:
        traceback.print_exc()
        makefile_config = ['$(error Error occurred in checkout)']

    config_path = os.path.join(output_path, "configuration.mk")
    with open(config_path, "w") as f:
        f.write('\n'.join(makefile_config) + '\n')
    # Print path so that the generated file can be included in one go
    print(config_path)


if __name__ == '__main__':
    main(sys.argv[1:])
