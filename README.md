# LHCb stack development tools

## Get started

Chose a workspace directory, e.g. `stack`, and run the following command

```sh
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/raw/mess/setup.py | python - stack
```

The script will first check that all prerequisites are met. If it fails, check
[doc/prerequisites.md] for more information. Then it will clone this repo
inside a new directory `stack/utils` and do the initial setup. It will choose
a default environment for you.

Install recent (or patched) versions of CMake, Ninja, ccache and distcc.
It also installs a bunch of useful scripts and should take less than 5 minutes.

```sh
bash utils/install.sh
```

Configure your environment (e.g. docker or native) and projects to build

```sh
$EDITOR utils/config
$EDITOR utils/configuration.mk
```

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
make fast/Moore/test ARGS='-R hlt1_example'
# verbose output showing test (failure) details
make fast/Moore/test ARGS='-R hlt1_example -V'
```

## HOWTOs

### Change the platform

The platform set in your shell when running `make` or `run-env` is irrelevant.
In order to change the platform used to compile and run, do the following

```sh
git config --file utils/config platfrom.binaryTag x86_64-centos7-gcc8-opt+g
```

or edit the file `utils/config` directly.

### Update the setup

In case there is a fix or an update to the setup, you can do the following to
sync to the latest changes.

```sh
# TODO
```

## Known issues

- We don't know how to run over GRID files
- You MUST run the top-level `make` from the directory where it resides.
- Need to be able to run docker without sudo.
- You MUST be on the CERN network to profit from distcc.
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
- Settings are scattered in `configuration.mk`, `config`, `setup.sh`.
- `lb-docker-run` should be upstreamed and removed from this repo.
- One MUST NOT `make` directly in the project directories.
