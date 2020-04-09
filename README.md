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

Adjust the following command according to how you want the directory containing your stack to be called and then run it (here we use simply "`stack`"):

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/master/setup.py | python - stack
```

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

> __Note:__ the first time you `make`, some recent (or patched) versions of
> CMake, Ninja, ccache and distcc (plus a bunch of scripts) will be installed.
> This should take less than 5 minutes. If needed redo this step with
`rm -rf contrib; make contrib`

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
make Moore
# list available tests
make fast/Moore/test ARGS='-N'
# run all tests with 4 parallel jobs
make fast/Moore/test ARGS='-j 4'
# run test(s) matching a regex
make fast/Moore/test ARGS='-R hlt1_example$'
# verbose output showing test (failure) details
make fast/Moore/test ARGS='-R hlt1_example -V'
```

## Makefile instructions

The `Makefile` provided features the following targets.

* Global targets
  * `all` (or `build`): builds the default projects (this is the default target),
  * `clean`: remove build products for all cloned projects (keeping the sources and CMake cache),
  * `purge`: similar to `clean`, but also remove the CMake temporary files,
  * `help`: print a list of available targets,
  * `for-each CMD="do-something"`: run a command in each git repository (projects, data packages or other).
* Project targets
  * `<Project>`: build the required project (with dependencies),
  * `<Project>/<target>`: build the specified target in the given project,
    for example, to get the list of targets available in Gaudi you can call `make Gaudi/help`,
  * `<Project>-clean`: clean `<Project>` and the projects that depend on it
  * `fast/<Project>[/<target>]`: same as the target `<Project>[/<target>]`
    but do not try to build the dependencies.

## Integrations

### Visual Studio Code

There is experimental VS Code support via an auto-generated
configuration file (`stack.code-workspace`) for a
[multi-root workspace](https://code.visualstudio.com/docs/editor/multi-root-workspaces).
The file is updated every time you run `make`.
Currently, only intellisense for C++ and Python are supported and there are no
other integrations such as building and testing from within VS Code.
See [doc/vscode.md](/../tree/vscode/doc/vscode.md) for more information.

## Configuration settings

You can set the following options in `config.json` to configure your build setup.
Depending on what and where you build there are different recommendations.

- `defaultProjects`: Defines which projects are built when `make` is invoked without giving any
  project-specific target (i.e. `make`, `make all` or `make build`).
- `useDocker (true/false)`: Allows running with docker, check
  [doc/prerequisites.md](doc/prerequisites.md) for instructions.
  Defaults to false on CentOS7, otherwise is true.
- `distcc ([true]/false)`: distcc allows to compile remotely on machines located at CERN.
  Currently 80 virtual cores are available for parallel compilation.
  You need a valid kerberos token and connectivity to lxplus (or to be inside the CERN network).
  Be aware that these are shared resources, set it to `false` if your local cluster is powerful.

All possible configuration settings and their defaults are stored in
[default-config.json](default-config.json).

## HOWTOs

### Change the platform

The platform set in your shell when running `make` or `run-env` is irrelevant.
In order to change the platform used to compile and run, do the following

```sh
utils/config.py binaryTag x86_64-centos7-gcc9-opt+g
```

or edit the file `utils/config.json` directly.

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
utils/config.py lcgVersion dev4
utils/config.py cmakePrefixPath '$CMAKE_PREFIX_PATH:/cvmfs/sft-nightlies.cern.ch/lcg/nightlies/dev4/Tue'
```

In order to use a Python 3 build of LCG, there is no need to select a Python 3 LCG
build explicitly, but it is sufficient to set the platform in the following way

```sh
utils/config.py binaryTag x86_64-centos7-gcc9+py3-opt
```

### Pass flags to CMake

In order to pass variables to CMake, you can pass `CMAKEFLAGS='-DVARIABLE=VALUE'`
when calling `make Project/configure`. This will pass the flags to `Project` but
also to any other dependent project that happens to need reconfiguring.

Alternatively, if you like to persist the flags you pass per project, set the appropriate
configuration setting, e.g.

```sh
utils/config.py cmakeFlags.Allen '-DSTANDALONE=OFF -DSEQUENCE=velo'
```

or use `cmakeFlags.default` to affect all projects.

### Update the setup

In case there is a fix or an update to the setup, just run `setup.py`

```sh
python utils/setup.py
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
    python - stack -b vscode
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
python setup.py --repo . path/to/new/stack
```

which will use the `HEAD` (i.e. the currently checked out branch) of your local
repo to create a new stack setup at the given path.
Note that uncommitted changes will not be in the new clone.

### Migrate from another stack setup

- Follow the [Get started](#get-started) instructions and stop before compiling.
- Copy your existing projects in the stack directory, where each project goes in
  a folder with the standard letter case found on GitLab (e.g. LHCb, Lbcom, Rec).
- Run `make purge` to delete all existing build products. Your code is safe.
- Run `make`. Required projects that you don't have (like Gaudi) will be
  cloned for you.

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

If you fixed it, great! If you think it's possible that someone else hits the
same problem, plese [open an issue](/../issues/new) or submit a merge request.

If you couldn't figure it out, seek help on
[Mattermost](https://mattermost.web.cern.ch/lhcb/messages/@rmatev)
or open an [open an issue](/../issues/new), ideally provinding steps to
reproduce the problem.

## Known issues

- We don't know how to run over GRID files
- You MUST run the top-level `make` from the directory where it resides.
- Need to be able to run docker without sudo.
- CMake emits a bunch of warnings.
    ```log
      No project() command is present.  The top-level CMakeLists.txt file must
      contain a literal, direct call to the project() command.  Add a line of
      code such as
    ```
- distcc is not happy about some of our generated files (can be ignored)
    ```log
    distcc[2541] (dcc_talk_to_include_server) Warning: include server gave up analyzing
    distcc[2541] (dcc_build_somewhere) Warning: failed to get includes from include server, preprocessing locally
    ```
- Manual initial setup can be improved with e.g. cookiecutter.
- `lb-docker-run` should be upstreamed and removed from this repo.
- Logging is not uniform, and worse not documented
- When using docker outside CERN, the port forwarding for distcc is done in
  the container, which makes it execute quite frequently and adds overhead.
