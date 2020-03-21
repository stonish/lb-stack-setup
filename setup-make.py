#!/usr/bin/python
"""Write project configuration in a makefile."""
from __future__ import print_function
import os
import re
import sys
from config import read_config

config = read_config()

try:
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


def parse_src_spec(spec):
    """Return name, url and branch from "group/project[:branch]"."""
    m = re.match(
        r'^(?P<fullname>([^/:]+/)+(?P<name>[^:]+))(:(?P<branch>[^:]+))?$',
        spec)
    if not m:
        raise ValueError("malformed source spec '{}'".format(spec))
    g = m.groupdict()
    return (g['name'], '{}/{}.git'.format(config['gitBase'], g['fullname']),
            g["branch"] or config['gitBranch']['default'])


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
    with open(os.path.join(project, 'CMakeLists.txt')) as f:
        cmake = f.read()
    m = re.search(r'gaudi_project\(([^\)]+)\)', cmake)
    return re.findall(r'\sUSE\s+(\w+)\s', m.group(1))


def clone(project):
    """Clone project and return canonical name."""
    if not os.path.isdir(project):
        m = [x for x in os.listdir('.') if x.lower() == project.lower()]
        assert len(m) <= 1, 'Multiple directories for project: ' + str(m)
        if not m:
            url, branch = git_url_branch(project)
            from subprocess import check_output
            check_output(['git', 'clone', url])
            check_output(['git', 'checkout', branch], cwd=project)
            check_output(
                ['git', 'submodule', 'update', '--init', '--recursive'],
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
        check_output([
            os.path.join(config['lbenvPath'], 'bin/git-lb-clone-pkg'),
            name
        ],
                     cwd=path)
        # TODO send output to stderr or log


def checkout(projects, data_packages):
    """Clone projects and data packagas, and return make configuration.

    The project dependencies of `projects` are cloned recursively.

    """
    to_checkout = list(projects)
    projects = []
    project_deps = {}

    while to_checkout:
        p = clone(to_checkout.pop(0))
        deps = cmake_deps(p)
        to_checkout.extend(sorted(set(deps).difference(projects)))
        projects.append(p)
        project_deps[p] = deps

    # Second pass once all projects are known to determine dependencies
    dependencies = {
        p: set(project_deps[p]).intersection(projects)
        for p in projects
    }
    inv_dependencies = {
        d: set(p for p in projects if d in dependencies[p])
        for d in projects
    }

    mkdir_p("DBASE")
    for name in data_packages:
        clone_package(name, "DBASE")

    makefile_config = [
        "PROJECTS := " + " ".join(projects),
        "DATA_PACKAGES := " + " ".join(data_packages),
    ]
    for p in projects:
        makefile_config += [
            "{}_DEPS := {}".format(p, ' '.join(dependencies[p])),
            "{}_INV_DEPS := {}".format(p, ' '.join(inv_dependencies[p])),
        ]

    return makefile_config


def main():
    # save the host environment where we're executed
    output_path = config['outputPath']
    mkdir_p(output_path)
    with open(os.path.join(output_path, 'host.env'), 'w') as f:
        for name, value in sorted(os.environ.items()):
            print(name + "=" + value, file=f)

    projects = []
    for arg in sys.argv[1:]:
        m = re.match(r'(fast/)?(?P<project>[A-Z]\w+)(/.+)?', arg)
        if m:
            projects.append(m.group('project'))
    projects = projects or [config['defaultProject']]

    try:
        makefile_config = checkout(projects, config['dataPackages'])
        makefile_config += ["CONTRIB_PATH := " + config["contribPath"]]
    except Exception as e:
        print(str(e), file=sys.stderr)
        makefile_config = ['$(error Error occurred in checkout)']

    config_path = os.path.join(output_path, "configuration.mk")
    with open(config_path, "w") as f:
        f.write('\n'.join(makefile_config) + '\n')
    # Print path so that the generated file can be included in one go
    print(config_path)


if __name__ == '__main__':
    main()
