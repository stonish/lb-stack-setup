# LHCb stack development tools

## Get started

First, choose and `cd` into a directory where your stack will reside,
for example, `$HOME` or `/afs/cern.ch/work/j/jdoe`.

> **Important:** You need at least **10 GiB** of free space to compile the stack for
> one `*-opt` platform, and **50 GiB** if you compile with debug symbols
> (`*-dbg` or `*-opt+g`).

Adjust the following command according to how you want the directory containing your stack to be called and then run it (here we use simply "`stack`"):

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/master/setup.py | python - stack
```

The script will first check that all prerequisites are met. If it fails, check
[doc/prerequisites.md](doc/prerequisites.md) for more information.
Then it will clone this repo inside a new directory `stack/utils` and do the
initial setup. It will choose a default environment for you.

Configure your setup (e.g. desired platform) and projects to build

```sh
$EDITOR utils/config.json
```

All configuration settings and their defaults are stored in
[default-config.json](default-config.json).
Any settings you specify `config.json` file will override the defaults.

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

## Integrations

### Visual Studio Code

Experimental VS Code support exists in the [vscode](/../tree/vscode) branch.
Currently, only intellisense for C++ and Python are supported and there are no
other integrations such as building and testing from within VS Code.
See [doc/vscode.md](/../tree/vscode/doc/vscode.md) for more information.

## HOWTOs

### Change the platform

The platform set in your shell when running `make` or `run-env` is irrelevant.
In order to change the platform used to compile and run, do the following

```sh
utils/config.py binaryTag x86_64-centos7-gcc9-opt+g
```

or edit the file `utils/config.json` directly.

### Update the setup

In case there is a fix or an update to the setup, just run `setup.py`

```sh
utils/setup.py
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
