#!/usr/bin/env python3
"""Write project configuration in a makefile."""
from __future__ import print_function
import glob
import itertools
import os
import pathlib
import re
from subprocess import CalledProcessError
import traceback
import shutil
import sys
from concurrent.futures.thread import ThreadPoolExecutor
from config import read_config, DIR, GITLAB_READONLY_URL, GITLAB_BASE_URLS
from utils import (
    setup_logging,
    run,
    run_nb,
    topo_sorted,
    add_file_to_git_exclude,
    write_file_if_different,
    is_file_too_old,
    is_file_older_than_ref,
)
from vscode import write_vscode_settings

DATA_PACKAGE_DIRS = ["DBASE", "PARAM"]
SPECIAL_TARGETS = ["update", "report"]
MAKE_TARGET_RE = re.compile(
    r'^(?P<fast>fast/)?(?P<project>[A-Z]\w+)(/(?P<target>.*))?$')

config = None
log = None


def data_package_container(name):
    parts = name.split('/', 1)
    if len(parts) > 1:
        if parts[0] in DATA_PACKAGE_DIRS:
            container, package = parts
    else:
        param_packages = [
            "BcVegPyData", "ChargedProtoANNPIDParam", "Geant4Files",
            "GenXiccData", "MCatNLOData", "MIBData", "ParamFiles",
            "QMTestFiles", "TMVAWeights"
        ]
        package = name
        container = "PARAM" if name in param_packages else "DBASE"
    return container, package


class NotCMakeProjectError(RuntimeError):
    pass


def symlink(src, dst):
    """Create a symlink only if not already existing and equivalent."""
    src_check = (src if src.startswith('/') else os.path.join(
        os.path.dirname(dst), src))
    if os.path.realpath(dst) == os.path.realpath(src_check):
        return
    if os.path.isfile(dst) or os.path.islink(dst):
        os.remove(dst)
    log.debug(f"Creating symlink {dst} -> {src}")
    os.symlink(src, dst)


def git_url_branch(repo, try_read_only=False):
    if repo == 'utils':
        return None, 'master'
    path_parts = pathlib.PurePath(repo).parts
    is_data_package = path_parts[0] in DATA_PACKAGE_DIRS
    default_key = 'defaultDataPackages' if is_data_package else 'default'
    if is_data_package:
        # For data packages we only look up e.g. 'AppConfig' in the
        # gitUrl, gitGroup, gitBranch settings and not 'DBASE/AppConfig'
        repo = os.path.join(*path_parts[1:])

    url = config['gitUrl'].get(repo)
    if not url:
        group = config['gitGroup']
        group = group.get(repo, group[default_key])
        url = '{}/{}/{}.git'.format(config['gitBase'], group, repo)
    if try_read_only:
        # Swap out the base for the read-only base
        for base in GITLAB_BASE_URLS:
            if url.startswith(base):
                url = GITLAB_READONLY_URL + url[len(base):]
                break
    branch = config['gitBranch']
    branch = branch.get(repo, branch[default_key])
    return url, branch


def cmake_name(project):
    with open(os.path.join(project, 'CMakeLists.txt')) as f:
        cmake = f.read()
    m = re.search(
        r'\s+(gaudi_)?project\(\s*(?P<name>\w+)(\s|\))',
        cmake,
        flags=re.IGNORECASE)
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
        m = re.search(r'(\n|^)dependencies:\s(?P<deps>(\s+-\s+\w+(\n|$))+)',
                      metadata)
        if not m:
            raise RuntimeError(f'dependencies not found in {metadata_path}')
        deps = [s.strip(' -') for s in m.group('deps').splitlines()]
        deps = [d for d in deps if d not in IGNORED_DEPENDENCIES]
        local_deps = [d for d in deps if d not in config['cvmfsProjects']]
        cvmfs_deps = {
            d: config['cvmfsProjects'][d]
            for d in deps if d in config['cvmfsProjects']
        }
    except IOError:
        # Fall back to old-style cmake
        local_deps = old_cmake_deps(project)
        if config['cvmfsProjects']:
            raise RuntimeError("cvmfsProjects not supported with old CMake")
        cvmfs_deps = {}
    return (local_deps + config['extraDependencies'].get(project, []),
            cvmfs_deps)


def clone_cmake_project(project):
    """Clone project and return canonical name.

    When cloning, if necessary, the directory is renamed to the
    project's canonical name as specified in the CMakeLists.txt.
    Nothing is done if the project directory already exists.

    """
    assert project not in config['cvmfsProjects']
    m = [x for x in os.listdir('.') if x.lower() == project.lower()]
    assert len(m) <= 1, 'Multiple directories for project: ' + str(m)
    if not m:
        url, branch = git_url_branch(project)
        log.info(f'Cloning {project}...')
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


def package_major_version(path):
    """Return the major part (v3) of a data package version."""
    try:
        with open(os.path.join(path, 'cmt/requirements')) as f:
            requirements = f.read()
    except FileNotFoundError:
        return None

    m = re.search(
        r'^\s*version\s+(v[0-9]+)r[0-9]+', requirements, flags=re.MULTILINE)
    return m.group(1) if m else None


def clone_package(name, path):
    full_path = os.path.join(path, name)
    if not os.path.isdir(full_path):
        log.info(f'Cloning {name}...')
        url, branch = git_url_branch(full_path)
        run(['git', 'clone', url, full_path])
        run(['git', 'checkout', branch], cwd=full_path)

    # Create symlinks instead of the usual subdirectory as the new CMake
    # has some issue with locating them as created by git-lb-clone-pkg.
    major_version = package_major_version(full_path)
    version_symlinks = ([major_version + 'r999']
                        if major_version else []) + ['v999r999']
    for v in version_symlinks:
        full_path_v = os.path.join(full_path, v)
        # the next line fixes the case when old clones are lying around
        shutil.rmtree(full_path_v, ignore_errors=True)
        symlink('.', full_path_v)
    # Remove obsolete symlinks if needed
    for v in os.listdir(full_path):
        if v in version_symlinks:
            continue
        full_path_v = os.path.join(full_path, v)
        if re.match("^v[0-9]+r[0-9]+$", v) and os.path.islink(full_path_v):
            os.remove(full_path_v)

    return full_path


def list_repos(dirs=['']):
    """Return all git repositories under the given directories.

    Excludes the `utils` directory.

    """
    all_paths = []
    for d in dirs:
        paths = [p[:-5] for p in glob.glob(os.path.join(d, '*/.git'))]
        all_paths += sorted(p for p in paths if os.path.abspath(p) != DIR)
    return all_paths


def check_staleness(repos, show=1):
    FETCH_TTL = 3600  # seconds
    # Here we assume that having FETCH_HEAD also fetched our branch
    # from our remote.
    to_fetch = [
        p for p in repos
        if is_file_too_old(os.path.join(p, '.git', 'FETCH_HEAD'), FETCH_TTL)
    ]

    def fetch_repo(path):
        url, branch = git_url_branch(path, try_read_only=True)
        url = url or "origin"  # for utils
        # Check if `branch` is a branch
        fetch_args = [url, f"refs/heads/{branch}:refs/remotes/origin/{branch}"]
        result = run(
            ['git', 'fetch'] + fetch_args, cwd=path, check=False, log=True)
        if result.returncode == 0:
            return
        # Check if `branch` is a tag
        fetch_args = [url, "refs/tags/{branch}:refs/tags/{branch}"]
        result = run(
            ['git', 'fetch'] + fetch_args, cwd=path, check=False, log=True)
        if result.returncode == 0:
            return
        # `branch` must be a commit SHA, it should be fetched manually
        log.debug(f"Assuming {branch} is a commit SHA")

    if to_fetch:
        log.info("Fetching {}".format(', '.join(to_fetch)))
        with ThreadPoolExecutor(max_workers=64) as executor:
            # list() to propagate exceptions
            list(executor.map(fetch_repo, to_fetch))

    def compare_head(path):
        ref = git_url_branch(path)[1]
        try:
            # FIXME the following can be simplified by parsing the output of
            # git show-ref refs/remotes/origin/{ref} refs/tags/{ref}
            for check in [False, True]:
                # First check if the target is a branch, tag or not (i.e. tag/SHA)
                res = run([
                    'git', 'show-ref', '--verify', f'refs/remotes/origin/{ref}'
                ],
                          cwd=path,
                          check=False,
                          log=False)
                target = 'origin/' + ref if res.returncode == 0 else ref

                res = run([
                    'git', 'rev-list', '--count', '--left-right',
                    f'{target}...'
                ],
                          cwd=path,
                          check=check,
                          log=False)
                if res.returncode == 0:
                    break
                fetch_repo(path)
            n_behind, n_ahead = map(int, res.stdout.split())

            target_refs = run(
                [
                    'git', 'log', '-n1', '--pretty=%C(auto)%h',
                    '--color=always', '--abbrev=10', target
                ],
                cwd=path,
                log=False,
            ).stdout.strip()

            # using %d instead of %D and  -c log.excludeDecoration=...
            # for backward compatibility with git 1.8
            local_refs = run(
                [
                    'git', '-c', 'log.excludeDecoration=*/HEAD', 'log', '-n1',
                    '--pretty=%C(auto)%h,%d', '--color=always', '--abbrev=10'
                ],
                cwd=path,
                log=False,
            ).stdout.strip()
            local_refs = re.sub(r"HEAD -> |\(|\)", "", local_refs)

            status = None
            if show >= 2:
                res = run(
                    ['git', '-c', 'color.status=always', 'status', '--short'],
                    cwd=path,
                    check=False,
                    log=False)
                status = res.stdout.rstrip()

            return (path, n_behind, n_ahead, local_refs, target, target_refs,
                    status)

        except (CalledProcessError, ValueError):
            log.warning('Failed to get status of ' + path)

    with ThreadPoolExecutor(max_workers=64) as executor:
        res = [r for r in executor.map(compare_head, repos) if r is not None]

    res = sorted(res, key=lambda x: repos.index(x[0]))
    res = [r for r in res if r[1] or (r[2] and show >= 1) or show >= 2]
    width = max(len(r[0]) for r in res) if res else 0
    for (path, n_behind, n_ahead, local_refs, target, target_refs,
         status) in res:
        import textwrap
        status = "\n" + textwrap.indent(status, " " *
                                        (width + 5)) if status else ""
        if n_behind:
            msg_n_ahead = "" if not n_ahead else f" ({n_ahead} ahead)"
            log.warning(
                f"{path:{width}} ({local_refs}) is \x1b[1m{n_behind} commits "
                f"behind\x1b[22m{msg_n_ahead} {target} ({target_refs}){status}"
            )
        elif n_ahead:
            log.info(f"{path:{width}} ({local_refs}) is {n_ahead} commits "
                     f"ahead {target} ({target_refs}){status}")
        else:
            log.info(f"{path:{width}} is at {target} ({target_refs}){status}")


def update_repos():
    log.info("Updating projects and data packages...")
    root_repos = list_repos()
    dp_repos = list_repos(DATA_PACKAGE_DIRS)
    projects = topo_sorted(find_all_deps(root_repos, {}))
    missing = [p for p in projects if not os.path.isdir(p)]
    if missing:
        log.warning(f"Dependency projects not cloned: {','.join(missing)}")
    repos = [p for p in projects if p not in missing] + dp_repos

    # Skip repos where the tracking branch does not match the config
    # or nothing is tracked (e.g. a tag is checked out).
    not_tracking = []
    ps = [
        run_nb(['git', 'rev-parse', '--abbrev-ref', 'HEAD@{upstream}'],
               cwd=repo,
               check=False) for repo in repos
    ]
    for repo, get_result in zip(repos, ps):
        res = get_result()
        if res.returncode == 0:
            _, branch = git_url_branch(repo, try_read_only=True)
            tracking_branch = res.stdout.strip().split('/', 1)[1]
            if branch != tracking_branch:
                not_tracking.append(repo)  # tracking a non-default branch
        else:
            not_tracking.append(repo)
    tracking = [r for r in repos if r not in not_tracking]

    ps = []
    for repo in tracking:
        url, branch = git_url_branch(repo, try_read_only=True)
        ps.append(
            run_nb(
                [
                    'git', '-c', 'color.ui=always', 'pull', '--ff-only', url,
                    f"{branch}:refs/remotes/origin/{branch}"
                ],
                cwd=repo,
                check=False,
            ))
    up_to_date = []
    update_failed = []
    for repo, get_result in zip(tracking, ps):
        res = get_result()
        if res.returncode == 0:
            if 'Already up to date.' in res.stdout:
                up_to_date.append(repo)
            else:
                log.info(f"{repo}: {res.stdout.strip()}\n")
        else:
            log.warning(f'{repo}: FAIL\n\n{res.stderr.strip()}\n')
            update_failed.append(repo)
    log.info(f"Up to date: {', '.join(up_to_date)}.")
    if not_tracking:
        log.warning("Skipped repos not tracking the default branch: "
                    f"{', '.join(not_tracking)}.")
    check_staleness(not_tracking + update_failed, show=0)
    if update_failed:
        log.warning(f"Update failed for: {', '.join(update_failed)}.")


def report_repos():
    for env_file in ["make.sh.env", "project.mk.env"]:
        env_path = os.path.join(config['outputPath'], env_file)
        with open(env_path) as f:
            log.info(f"Environment from {env_path}\n{f.read().strip()}")

    root_repos = list_repos()
    dp_repos = list_repos(DATA_PACKAGE_DIRS)
    projects = topo_sorted(find_all_deps(root_repos, {}))
    repos = projects + dp_repos + ["utils"]
    check_staleness(repos, show=2)


def checkout(projects, data_packages):
    """Clone projects and data packages, and return make configuration.

    The project dependencies of `projects` are cloned recursively.

    """
    project_deps = {}
    to_checkout = list(projects)
    while to_checkout:
        p = to_checkout.pop(0)
        p = clone_cmake_project(p)
        deps, cvmfs_deps = find_project_deps(p)
        to_checkout.extend(sorted(set(deps).difference(project_deps)))
        project_deps[p] = deps
        # write cmake cache preload file to force dependency version
        preload_content = ""
        for dep, ver in cvmfs_deps.items():
            cmake_ver = ver.replace("v", "").replace("r", ".").replace(
                "p", ".")
            preload_content += f'set({dep}_EXACT_VERSION "{cmake_ver}" CACHE STRING "")\n'
        preload_fn = os.path.join(p, "cache_preload.cmake")
        if preload_content or os.path.isfile(preload_fn):
            write_file_if_different(preload_fn, preload_content)

    # Check that all dependencies are also keys
    assert set().union(*project_deps.values()).issubset(project_deps)

    if not projects:
        # do not checkout any data packages if no projects are needed
        data_packages = []

    dp_repos = []
    for spec in data_packages:
        container, name = data_package_container(spec)
        os.makedirs(container, exist_ok=True)
        dp_repos.append(clone_package(name, container))

    check_staleness(topo_sorted(project_deps) + dp_repos + ['utils'])

    return project_deps


def find_all_deps(repos, project_deps={}):
    project_deps = project_deps.copy()
    for r in repos:
        if r not in project_deps:
            try:
                project_deps[r], _ = find_project_deps(r)
            except NotCMakeProjectError:
                pass
    return project_deps


def inv_dependencies(project_deps):
    return {
        d: set(p for p, deps in project_deps.items() if d in deps)
        for d in project_deps
    }


def install_contrib(config):
    # Install symlinks to external software such that CMake doesn't cache them
    LBENV_BINARIES = {
        'cmake': 'cmake',
        'ctest': 'ctest',
        'ninja': 'ninja',
        'ninja-build': 'ninja',  # to make sure we don't pick up an old binary
        'ccache': 'ccache',
    }
    os.makedirs(os.path.join(config['contribPath'], 'bin'), exist_ok=True)
    for tgt, src in LBENV_BINARIES.items():
        symlink(
            os.path.join(config['lbenvPath'], 'bin', src),
            os.path.join(config['contribPath'], 'bin', tgt))

    if config['useDistcc']:
        target = os.path.join(config['contribPath'], 'bin', "distcc")
        script = os.path.join(DIR, "install-distcc.sh")
        if is_file_older_than_ref(target, script):
            log.info("Installing distcc...")
            run([os.path.join(DIR, "build-env"), "bash", script], stdin=None)


def error(config_path, *args):
    log.error(*args)
    with open(config_path, "w") as f:
        f.write('$(error an error occurred)\n')
    print(config_path)
    exit()


def main(targets):
    global config, log
    config = read_config()
    log = setup_logging(config['outputPath'])
    output_path = config['outputPath']
    is_mono_build = config['monoBuild']

    # save the host environment where we're executed
    os.makedirs(output_path, exist_ok=True)
    with open(os.path.join(output_path, 'host.env'), 'w') as f:
        for name, value in sorted(os.environ.items()):
            print(name + "=" + value, file=f)

    # Override binaryTag if necessary
    binary_tag_override = os.getenv("BINARY_TAG_OVERRIDE")
    binary_tag_env = os.getenv("BINARY_TAG")
    binary_tag = config["binaryTag"]
    if binary_tag_override:
        binary_tag = binary_tag_override
    elif binary_tag_env:
        if not binary_tag:
            binary_tag = binary_tag_env
        elif binary_tag != binary_tag_env:
            exit(f"BINARY_TAG environment variable ({binary_tag_env}) and " +
                 f"binaryTag setting in config.json ({binary_tag}) are both " +
                 "set to conflicting values.\nPlease set just one of the two "
                 + "or invoke with " +
                 f"`make BINARY_TAG={binary_tag_env} {' '.join(targets)}` " +
                 "to force the platform.")
    config["binaryTag"] = binary_tag

    config_path = os.path.join(output_path, f"configuration-{binary_tag}.mk")

    # Separate out special targets
    special_targets = [t for t in SPECIAL_TARGETS if t in targets]
    targets = [t for t in targets if t not in SPECIAL_TARGETS]

    # Handle special targets
    if special_targets:
        if len(special_targets) > 1:
            error(
                config_path,
                f"expected at most one special target, got {special_targets}")
        if targets:
            error(config_path,
                  f"expected only special targets, also got {targets}")
        target, = special_targets
        if target == "update":
            update_repos()
        elif target == "report":
            report_repos()
        else:
            raise NotImplementedError(f"unknown special target {target}")
        return

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
    if ('build' in targets or 'all' in targets
            or not targets) and not is_mono_build:
        build_target_deps = config['defaultProjects']
        projects += build_target_deps
    else:
        build_target_deps = []

    if fast_checkout_projects and len(fast_checkout_projects) != len(targets):
        error(
            config_path, "fast/Project/checkout targets cannot be mixed " +
            "with other targets")

    install_contrib(config)

    if is_mono_build:
        # mono build links
        os.makedirs("mono", exist_ok=True)
        symlink(
            os.path.join(DIR, 'CMakeLists.txt'),
            os.path.join("mono", "CMakeLists.txt"))
        for wrapper in ["run", "gdb"]:
            target = os.path.join("mono", wrapper)
            symlink(os.path.join(DIR, f'project-{wrapper}.sh'), target)
        write_file_if_different(
            os.path.join("mono", ".ignore"), "# ripgrep ignore\n*\n")

    try:
        # Clone projects without following their dependencies and without
        # making any real target, e.g. `make fast/Moore/checkout`.
        for p in fast_checkout_projects:
            clone_cmake_project(p)

        # Clone data packages and projects to build with dependencies.
        data_packages = config['dataPackages']
        if not is_mono_build:
            project_deps = checkout(projects, data_packages)
        else:
            project_deps = checkout(config['defaultProjects'], data_packages)
            other_projects = list(set(projects) - set(project_deps))
            if other_projects:
                error(
                    config_path,
                    "When monoBuild is true, you must add all necessary " +
                    f"projects to defaultProjects. Missing: {other_projects}")

        projects_sorted = topo_sorted(project_deps)

        if is_mono_build:
            # generate a cmake file with the list of projects (to include in CMakeLists.txt)
            write_file_if_different(
                os.path.join(output_path, "mono_projects.cmake"),
                "set(PROJECTS {})\n".format(" ".join(projects_sorted)))

        for project in projects_sorted:
            # Create runtime wrappers and hide them from git
            for wrapper in ["run", "gdb"]:
                target = os.path.join(project, wrapper)
                symlink(os.path.join(DIR, f'project-{wrapper}.sh'), target)
                add_file_to_git_exclude(project, wrapper)
            # Also hide .env files
            add_file_to_git_exclude(project, ".env")

        # After we cloned the minimum necessary, check for other repos
        repos = list_repos()
        dp_repos = list_repos(DATA_PACKAGE_DIRS)

        # Find cloned projects that we won't build but that may be
        # dependent on those to build.
        project_deps = find_all_deps(repos, project_deps)

        # Order repos according to dependencies
        project_order = topo_sorted(project_deps) + repos
        repos.sort(key=lambda x: project_order.index(x))

        makefile_config = [
            "export BINARY_TAG := {}".format(config["binaryTag"]),
            "BUILD_PATH := {}".format(config["buildPath"]),
            "MONO_BUILD := " + str(int(is_mono_build)),
            "PROJECTS := " + " ".join(projects_sorted),
            "ALL_PROJECTS := " + " ".join(sorted(project_deps)),
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

    stats_timestamp = (
        f"{output_path}/stats/{config['binaryTag']}/start.timestamp")
    os.makedirs(os.path.dirname(stats_timestamp), exist_ok=True)
    with open(stats_timestamp, "w") as f:
        pass

    with open(config_path, "w") as f:
        f.write('\n'.join(makefile_config) + '\n')
    # Print path so that the generated file can be included in one go
    print(config_path)


if __name__ == '__main__':
    main(sys.argv[1:])
