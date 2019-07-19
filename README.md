# LHCb stack development tools

## Get started

> **Important:** This setup relies on some very recent fixes and improvements
> in external software (see below).

Choose a workspace directory, for example, `stack`, and run the following command

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
$EDITOR utils/configuration.mk
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
# run test(s) matching a regex (escape $ as $$)
make fast/Moore/test ARGS='-R hlt1_example$$'
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
utils/config.py binaryTag x86_64-centos7-gcc8-opt+g
```

or edit the file `utils/config.json` directly.

### Update the setup

In case there is a fix or an update to the setup, just pull the latest master
and verify your configuration (to catch issues with new or modified settings).

```sh
cd utils && git pull && cd ..
utils/config.py
```

Then, try to build again and follow any instructions you may get.
If that is not sufficient (e.g. because the toolchain changed),
the best is to purge all your projects with

```sh
make purge
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
- `TMVAImpFactory-MCUpTuneV1.cpp` takes forever to compile.
    ```log
    [8>1>1183/1191] Building CXX object Rec/ChargedProtoANNPID/CMakeFiles/ChargedProtoANNPID.dir/src/TMVAImpFactory-MCUpTuneV1.cpp.o
    distcc[3977] (dcc_select_for_read) ERROR: IO timeout
    distcc[3977] (dcc_r_token_int) ERROR: read failed while waiting for token "DONE"
    distcc[3977] (dcc_r_result_header) ERROR: server provided no answer. Is the server configured to allow access from your IP address? Is the server performing authentication and your client isn't? Does the server have the compiler installed? Is the server configured to access the compiler?
    distcc[3977] Warning: failed to distribute ../Rec/ChargedProtoANNPID/src/TMVAImpFactory-MCUpTuneV1.cpp to lbquantaperf02.cern.ch/40,cpp,lzo,auth, running locally instead
    ```
- There are no tests. None whatsoever.
- Manual initial setup can be improved with e.g. cookiecutter.
- Settings are scattered in `configuration.mk` and `default-config.json`.
- `lb-docker-run` should be upstreamed and removed from this repo.
- Logging is not uniform, and worse not documented
- When using docker outside CERN, the port forwarding for distcc is done in
  the container, which makes it execute quite frequently and adds overhead.
