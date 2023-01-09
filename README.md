# LHCb stack development tools

## Get started

First, choose and `cd` into a directory where your stack will reside,
for example, `$HOME` or `/afs/cern.ch/work/j/jdoe`.

> **Important:** You need at least **10 GiB** of free space to compile the stack for
> one `*-opt` platform, and **50 GiB** if you compile with debug symbols
> (`*-dbg` or `*-opt+g`).

> **Note:** Working on network file systems such as AFS or on network-backed
> volumes (e.g. on CERN OpenStack) is typically slower than on a local disk,
> especially if the latter is an SSD.

> **Note:** A good hybrid solution is to put the source code (few GiB) in your
> backed up home (e.g. AFS/NFS) and put the build artifacts in a bigger and faster
> local storage (that may not be backed up). See below how to do this using
> the [`buildPath`](#configuration-settings) setting.

Adjust the following command according to how you want the directory containing your stack to be called and then run it (here we use simply "`stack`"):

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/master/setup.py | python3 - stack
```

> **Note:** If your system lacks Python 3 (`/usr/bin/python3`), ask for it to
> be installed, or simply source the LHCb environment with
> `source /cvmfs/lhcb.cern.ch/lib/LbEnv` if it is not already sourced.

> **Note:** If you are working in the LHCb Online network (e.g. pluscc and __not__ lxplus),
> set up git with
> ```
> hostname --fqdn | grep -q lbdaq.cern.ch && git config --global 'http.https://github.com/.proxy' lbproxy01:8080
> ```
> to use the proxy to access GitHub.
> If you use VSCode with Remote - SSH , see also
> [doc/vscode.md](doc/vscode.md#using-remote-with-a-server-in-a-restricted-network)

The script will first check that all prerequisites are met. If it fails, check
[doc/prerequisites.md](doc/prerequisites.md) for more information.
Then it will clone this repo inside a new directory `stack/utils` and do the
initial setup. It will choose a default environment for you ("native" build on
CentOS 7 and docker on other OSes).

Configure your setup (e.g. desired platform) and projects to build

```sh
$EDITOR utils/config.json
```

All possible configuration settings and their defaults are stored in
[default-config.json](default-config.json).
Any settings you specify in the `config.json` file will override the defaults.
When you override dictionary values (e.g. `cmakeFlags`), the dictionary in
`config.json` will be merged with the one in `default-config.json`.
See [below](#configuration-settings) for some of the available settings and their use.

## Compile

You are now ready to go! Type `make [Project]` which will checkout all relevant
projects and build them. It can take some time.

```sh
make Moore
```

For example, building from Gaudi up until Moore takes 40 min on a mobile i5 CPU
with 2 physical cores.

## Run

Run jobs in the right environment with

```sh
utils/run-env Moore gaudirun.py #...
# or simply
Moore/run gaudirun.py #...
```

## Test

Below you see commands used in a typical testing workflow.

```sh
# make project and dependencies
make Moore  # or equivalently, make Moore/
# list available tests
make fast/Moore/test ARGS='-N'
# run all tests with 4 parallel jobs
make fast/Moore/test ARGS='-j 4'
# run test(s) matching a regex
make fast/Moore/test ARGS='-R hlt1_example$'
# verbose output showing test (failure) details
make fast/Moore/test ARGS='-R hlt1_example -V'
# running the mdf_read automatically runs the dependency mdf_write
make fast/Moore/test ARGS='-R mdf_read'
# to ignore all dependencies and only run mdf_read
make fast/Moore/test ARGS='-R mdf_read -FA .*'
```

Using `ARGS` you can pass arbitrary arguments to
[`ctest`](https://cmake.org/cmake/help/latest/manual/ctest.1.html).
Check the documentation for other useful arguments (e.g. `--stop-on-failure`
and `--rerun-failed`).

Note that changes in python sources are immediately "applied" in downstream projects
(unlike a "manual" stack setup with `lb-project-init`). For example, after changing a
`.py` in LHCb, you can do `Moore/run` or `make Moore/test ...` without having to
`make Moore` first.

> **Warning:** the above feature was broken by the new CMake, so for the time being
> always run `make Moore` after changes in upstream projects.
> See https://gitlab.cern.ch/rmatev/lb-stack-setup/-/issues/60

## Makefile instructions

The `Makefile` provided features the following targets.

- Global targets
  - `all` (or `build`): builds the default projects (this is the default target),
  - `clean`: remove build products for all cloned projects (keeping the sources and CMake cache),
  - `purge`: similar to `clean`, but also remove the CMake temporary files,
  - `update`: pull remote updates for repos which are on the default branch,
  - `help`: print a list of available targets,
  - `for-each CMD="do-something"`: run a command in each git repository (projects, data packages or other).
- Project targets
  - `<Project>`: build the required project (with dependencies),
  - `<Project>/`: same as the above,
  - `<Project>/<target>`: build the specified target in the given project,
    for example, to get the list of targets available in Gaudi you can call `make Gaudi/help`,
  - `<Project>-clean`: clean `<Project>` and the projects that depend on it
  - `fast/<Project>[/<target>]`: same as the target `<Project>[/<target>]`
    but do not try to build the dependencies,
  - `fast/<Project>/checkout`: just checkout `<Project>` without its dependencies.

## Monolithic builds (experimental)

Thanks to the modern CMake configuration, we can build all projects into
one monolithic build. Some pros of this way of build are:

- Save space and time by not copying files to InstallArea.
- Can set breakpoints in the sources in upstream projects (not in InstallArea).
- Jumping to definition (intellisense) leads to the sources.
- The overall configure time is shorter (but re-configuring always goes through all projects).

Enable the monolithic build by setting

```sh
utils/config.py monoBuild true
```

The `defaultProjects` setting is more important, it must contain the superset of
projects you work with (it defines which projects are configured).

The make targets are slightly different (no `fast/Project`, no `Project/purge`).
See `make help` for a complete list. _TODO_ describe targets in detail.
A typical workflow would be:

```sh
make Moore
make Moore/test ARGS='-N'
mono/run gaudirun.py ...
```

## Integrations

### Visual Studio Code

There is VS Code support via an auto-generated
[multi-root workspace](https://code.visualstudio.com/docs/editor/multi-root-workspaces)
configuration file (`stack.code-workspace`)
and per-project configuration files (`Project/.vscode/settings.json`).
The file is updated every time you run `make` and you can force an update
with `make stack.code-workspace` (e.g. in case you modified `template.code-workspace`).
Currently, intellisense for C++ and Python, and debugging configurations are supported.
There are no other integrations such as building and testing from within VS Code.
See [doc/vscode.md](doc/vscode.md) for more information, including some demos.

## Configuration settings

You can set the following options in `config.json` to configure your build setup.
Depending on what and where you build there are different recommendations.

- `binaryTag`: Default platform to use. The value is used to set the BINARY_TAG environment
  variable when building. The value can be overridden for a particular invocation of `make`
  with `make BINARY_TAG=<other binary tag> <target>`. Alternatively, set the value to an
  empty string in `config.json` and export it before running make: `BINARY_TAG=... make <target>`.
- `defaultProjects`: Defines which projects are built when `make` is invoked without giving any
  project-specific target (i.e. `make`, `make all` or `make build`).
- `targetBuildPath` and `ccachePath`: Defines where the build artifacts are stored. By default, they
  are put under the stack directory (and the respective projects inside). Instead, you can put
  the artifacts in a separate directory/volume, with something like this:

    ```sh
    utils/config.py ccachePath      '/localdisk1/$USER/ccache/$BINARY_TAG'
    utils/config.py targetBuildPath '/localdisk2/$USER/build/$HOSTNAME/${projectPath}'
    ```

- `useDocker (true/false)`: Allows running with docker, check
  [doc/prerequisites.md](doc/prerequisites.md) for instructions.
  Defaults to false on CentOS7, otherwise is true.
- `distcc ([true]/false)`: distcc allows to compile remotely on machines located at CERN.
  Currently 80 virtual cores are available for parallel compilation.
  You need a valid kerberos token and connectivity to lxplus (or to be inside the CERN network).
  Be aware that these are shared resources, set it to `false` if your local cluster is powerful.
- `forwardEnv (list)`: A list of environment variables that should be propagated
  to the build and runtime environment. You may use it for variables such as `GITCONDDBPATH`.
- `vscodeWorkspaceSettings`: include custom VSCode settings in the `.code-workspace` file.
  For example, one can customize the color of the window title bar with

    ```json
    "vscodeWorkspaceSettings": {
      "workbench.colorCustomizations": {
        "titleBar.activeBackground": "#a75555",
        "titleBar.activeForeground": "#ffffff"
      }
    }
    ```

All possible configuration settings and their defaults are stored in
[default-config.json](default-config.json).

## HOWTOs

### Change the platform

The platform set in your shell when running `make` or `run-env` is irrelevant.
In order to change the platform used to compile and run, do the following

```sh
utils/config.py binaryTag x86_64_v3-centos7-gcc11-opt
```

or edit the file `utils/config.json` directly.

You can also temporarily override the `binaryTag` setting when running `make`
or the run scripts:

```sh
make BINARY_TAG=x86_64_v3-centos7-gcc11-opt Moore
BINARY_TAG_OVERRIDE=x86_64_v3-centos7-gcc11-opt Moore/run
```

### Add a data package

By default only [PRConfig](https://gitlab.cern.ch/lhcb-datapkg/PRConfig) and
[AppConfig](https://gitlab.cern.ch/lhcb-datapkg/AppConfig) are cloned.
You can add a new package to be checked out in the json configuration.

> __Note:__ After adding a new data package, do a purge in the projects where you
> need it (e.g. `make Project/purge`) in order for CMake to pick it up.

> __Note:__ All data packages are put under `DBASE`, even those that nominally
> belong to `PARAM`. This does not affect the builds in any way.

### Use special LCG versions

LCG releases that are not installed under `/cvmfs/lhcb.cern.ch/` are picked up from
`/cvmfs/sft.cern.ch/` (see the `cmakePrefixPath` setting).

The EP-SFT groups provides cvmfs installations of
[special LCG flavours or nightly builds](http://lcginfo.cern.ch/).
For example, in order to use the `dev4` nightly build from Tuesday, it is enough to do

```sh
git -C Detector switch v0-patches  # master requires GitCondDB which is not available in the toolchain
utils/config.py lcgVersion dev4/Tue
utils/config.py cmakePrefixPath '$CMAKE_PREFIX_PATH:/cvmfs/sft-nightlies.cern.ch/lcg/nightlies/dev4/Tue'
```

### Pass flags to CMake

In order to pass variables to CMake, you can pass `CMAKEFLAGS='-DVARIABLE=VALUE'`
when calling `make Project/configure`. This will pass the flags to `Project` but
also to any other dependent project that happens to need reconfiguring.

Alternatively, if you like to persist the flags you pass per project, set the appropriate
configuration setting, e.g.

```sh
utils/config.py -- cmakeFlags.Allen '-DSTANDALONE=OFF -DSEQUENCE=velo'
utils/config.py -- cmakeFlags.Moore '-DLOKI_BUILD_FUNCTOR_CACHE=OFF'
```

or use `cmakeFlags.default` to affect all projects.

### Pass options to Ninja

To pass command line options to Ninja, you can pass the `BUILDFLAGS` variable to `make`.
For example, to override the default number of concurrent compilations to 2, run

```sh
make Rec BUILDFLAGS='-j 2'
```

### Use DD4hep

To use DD4hep it is enough to switch to a platform with `+dd4hep` added after the compiler,
for example

```sh
utils/config.py binaryTag x86_64_v2-centos7-gcc11+dd4hep-opt
```

### Building Gauss

Gauss typically requires some MRs to be applied on top
of the default branch use in the nightlies. This is reflected in the nightly
slot definitions (by using HEAD as version) and you can see the exact set of
MRs applied at the Gauss checkout page of a given build.

Below are two examples of how to get a checkout locally. They correspond to the
[lhcb-master/1767](https://lhcb-nightlies.web.cern.ch/nightly/lhcb-master/1767/) build.

#### Checkout and apply MRs manually

(Adapt list of MRs according to what you need.)

```sh
make fast/Gauss/checkout  # clone Gauss if not already there
git -C Gauss fetch && git fetch origin '+refs/merge-requests/*/head:refs/remotes/origin/mr/*'
git -C Gauss checkout origin/master
git -C Gauss merge --no-edit origin/mr/845 origin/mr/861
```

#### Checkout the nightly tags

The nightlies create a tag for each project and for each build. These tags can be used as follows

```sh
make fast/Gauss/checkout  # clone Gauss if not already there
git -C Gauss fetch ssh://git@gitlab.cern.ch:7999/lhcb-nightlies/Gauss.git lhcb-master/1767
git -C Gauss checkout FETCH_HEAD
```

### Building Gauss on Gaussino

- (Temporarily) switch to LCG 101
- Configure Geant4 to build with multi-threaded support.
- Switch to `Futurev4` in Gauss
- Merge the MRs applied in the [lhcb-gaussino](https://lhcb-nightlies.web.cern.ch/nightly/lhcb-gaussino/) slot.
- You can also change the platform to dd4hep if you want to build that flavour.

```sh
utils/config.py lcgVersion 101

utils/config.py -- cmakeFlags.Geant4 '-DGEANT4_BUILD_MULTITHREADED=ON'

utils/config.py gitBranch.Gauss Futurev4
git -C Gauss switch Futurev4

make Gauss/checkout  # clone Gauss and Gaussino if not already there

git -C Gaussino fetch && git fetch origin '+refs/merge-requests/*/head:refs/remotes/origin/mr/*'
git -C Gaussino checkout origin/master
git -C Gaussino merge --no-edit origin/mr/{35,53,57,59,68,73,75}

git -C Gauss fetch && git fetch origin '+refs/merge-requests/*/head:refs/remotes/origin/mr/*'
git -C Gauss checkout origin/Futurev4
git -C Gauss merge --no-edit origin/mr/{800,812,827,847,848,850,856,870,872}
```

### Build a run2-patches stack

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/master/setup.py | python3 - run2-stack
cd run2-stack
utils/config.py gitBranch.default run2-patches
make DaVinci
```

### Update the setup

In case there is a fix or an update to the setup, just run `setup.py`

```sh
python3 utils/setup.py
```

It attempts to pull the latest `master` and to update your `config.json`.
Then, verify your configuration (to catch issues with new or modified settings).

```sh
utils/config.py
```

Finally, try to build again and follow any instructions you may get.
If that is not sufficient (e.g. because the toolchain changed),
the best is to purge all your projects with

```sh
make purge
```

### Use a non-standard branch of lb-stack-setup

You might want to use a branch other than `master` to try out a new feature
that is not merged yet.

If you start from scratch, you can normally just tweak the way you run
`setup.py`. For example, if you want to try out a branch called `vscode`, do

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/master/setup.py | \
    python3 - stack -b vscode
```

> __Note:__ In some rare cases, you might need to download `setup.py` not from
> `master` but from the branch in question.

If you already have a stack set up, first check out the branch you want in utils

```sh
cd utils
git fetch
git checkout vscode
```

then, rerun `setup.py`, giving the same branch name, so that your existing
configuration is made consistent with the new branch.

```sh
./setup.py -b vscode
```

### Develop lb-stack-setup

Once you have a clone of this repo (e.g. the `stack/utils` directory), you can run

```sh
python3 setup.py --repo . path/to/new/stack
```

which will use the `HEAD` (i.e. the currently checked out branch) of your local
repo to create a new stack setup at the given path.
Note that uncommitted changes will not be in the new clone.

### Use custom toolchains (LbDevTools and lcg-toolchains)

If you need to debug the toolchain, or use a custom version, you can do so by
cloning LbDevTools and prepending the path to the cmake directory to `cmakePrefixPath`:

```sh
git clone ssh://git@gitlab.cern.ch:7999/lhcb-core/LbDevTools.git
utils/config.py cmakePrefixPath "$(pwd)/LbDevTools/LbDevTools/data/cmake:\$CMAKE_PREFIX_PATH"
```

To use a local copy of the new-style CMake toolchains (currently only for Gaudi),
simply clone the repository in the stack directory:

```sh
git clone ssh://git@gitlab.cern.ch:7999/lhcb-core/lcg-toolchains.git
```

### Migrate from another stack setup

- Follow the [Get started](#get-started) instructions and stop before compiling.
- Copy your existing projects in the stack directory, where each project goes in
  a folder with the standard letter case found on GitLab (e.g. LHCb, Lbcom, Rec).
- Run `make purge` to delete all existing build products. Your code is safe.
- Run `make`. Required projects that you don't have (like Gaudi) will be
  cloned for you.

### Pass flags to docker

When running in docker, you might want to pass flags to the LHCb docker wrapper
`lb-docker-run`. You can do that by setting the `LB_DOCKER_RUN_FLAGS` environment
variable. For example, to mount the directory `/some/path` you would do

```sh
LB_DOCKER_RUN_FLAGS="-v /some/path" Moore/run gaudirun.py ...
```

### Troubleshooting

1. Check your configuration files `utils/config.json` and `utils/default-config.json`.
   Check how they are interpreted by running `utils/config.py`.
2. Check the content of your output directory (by default this is `.output`) and
   in particular look into
   - the log at `.output/log`
   - the host environment (in which you run `make`): `.output/host.env`
   - the LHCb "build-env" environment (in which `make.sh` is run):
     `.output/make.sh.env`
   - the compilation environment (in which `project.mk` is invoked):
     `.output/project.mk.env`
3. To see in detail what ninja executes, use `make Project VERBOSE=1`.

If you fixed it, great! If you think it's possible that someone else hits the
same problem, plese [open an issue](/../../issues/new) or submit a merge request.

If you couldn't figure it out, seek help on
[Mattermost](https://mattermost.web.cern.ch/lhcb/messages/@rmatev)
or open an [open an issue](/../../issues/new), ideally provinding steps to
reproduce the problem.

## Known issues

- VSCode integration
  - A `C/C++ Configuration Warnings` output window may appear once per session
    to tell you that compile_commands for some projects are not up-to-date.
    Build them in order not to get the warnings
- You MUST run the top-level `make` from the directory where it resides.
- Need to be able to run docker without sudo.
- distcc is not happy about some of our generated files (can be ignored)

    ```log
    distcc[2541] (dcc_talk_to_include_server) Warning: include server gave up analyzing
    distcc[2541] (dcc_build_somewhere) Warning: failed to get includes from include server, preprocessing locally
    ```

- Exception from xenv (LbEnv/1020): this is a race condition when creating the xenvc cache, just retry the build.

    ```log
    _pickle.UnpicklingError: pickle data was truncated
    ```

- [GitLab issues](/../../issues)
