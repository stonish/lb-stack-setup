# LHCb stack development tools

## Prerequisites
### Operating system
#### CentOS 7 (e.g. a shared machine)
Confirm that you are on CentOS 7 with
```sh
grep PRETTY_NAME /etc/os-release
# PRETTY_NAME="CentOS Linux 7 (Core)"
```
_TODO: write special instructions for lxplus_

#### Other than CentOS 7 (e.g. a laptop)
You need docker to run a CentOS 7 container.
Check that you have docker installed and usable
```sh
docker run --rm -it hello-world
# or
sudo docker run --rm -it hello-world
```
If not, go to [setup-docker].

_TODO: OSX caveats? Windows??_

### CVMFS
Check that you have the following CVMFS directories accessible:
```sh
ls -ld /cvmfs/lhcb.cern.ch /cvmfs/lhcbdev.cern.ch /cvmfs/sft.cern.ch
```
If not, go to [setup-cvmfs].

### Git
Check that you have at least `git 2.13`
```sh
git --version
```

## Get started
Create a workspace directory, e.g. `stack`, and clone this repo inside in a directory `utils`:
```sh
mkdir stack
cd stack
git clone -b mess ssh://git@gitlab.cern.ch:7999/rmatev/lb-stack-setup.git utils
```

Install recent (or patched) versions of CMake, Ninja, ccache and distcc. Also installs a bunch of useful scripts. It should take less than 5 minutes.
```sh
bash utils/install.sh
```

Link the main `Makefile`
```sh
ln -s utils/Makefile .
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
utils/run-env Moore gaudirun.py ...
```

## Known issues
- Need to be able to run docker without sudo.
- You MUST run the top-level `make` from the directory where it resides.
- You MUST be on the CERN network to profit from distcc.
- CMake emits a bunch of warnings.
```
  No project() command is present.  The top-level CMakeLists.txt file must
  contain a literal, direct call to the project() command.  Add a line of
  code such as
```
- distcc is not happy about some of our generated files (can be ignored)
```
distcc[2541] (dcc_talk_to_include_server) Warning: include server gave up analyzing
distcc[2541] (dcc_build_somewhere) Warning: failed to get includes from include server, preprocessing locally
```
- `TMVAImpFactory-MCUpTuneV1.cpp` takes forever to compile.
```
[8>1>1183/1191] Building CXX object Rec/ChargedProtoANNPID/CMakeFiles/ChargedProtoANNPID.dir/src/TMVAImpFactory-MCUpTuneV1.cpp.o
distcc[3977] (dcc_select_for_read) ERROR: IO timeout
distcc[3977] (dcc_r_token_int) ERROR: read failed while waiting for token "DONE"
distcc[3977] (dcc_r_result_header) ERROR: server provided no answer. Is the server configured to allow access from your IP address? Is the server performing authentication and your client isn't? Does the server have the compiler installed? Is the server configured to access the compiler?
distcc[3977] Warning: failed to distribute ../Rec/ChargedProtoANNPID/src/TMVAImpFactory-MCUpTuneV1.cpp to lbquantaperf02.cern.ch/40,cpp,lzo,auth, running locally instead
```
- There are no tests. None whatsoever.
- Manual initial setup can be improved with e.g. cookiecutter.
- Settings are scattered in `configuration.mk`, `binary_tag`, `setup.sh`.
- lb-docker-run should be upstreamed and removed from this repo.
