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
You are now ready to go! Hit `make [Project]` which will checkout all relevant
projects and build them. It can take some time.
```sh
make Moore
```

## Run
Run jobs in the right environment with
```sh
utils/run-env Moore gaudirun.py ...
```

## Known issues
- Need to be able to run docker without sudo
- You MUST run the top-level `make` from the directory where it resides.
- There are no tests. None whatsoever.
- Manual initial setup can be improved with e.g. cookiecutter.
- lb-docker-run should be upstreamed and removed from this repo.



