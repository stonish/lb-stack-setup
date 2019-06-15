# Prerequisites

## Operating system

### CentOS 7 (e.g. a shared machine)

Confirm that you are on CentOS 7 with

```sh
grep PRETTY_NAME /etc/os-release
# PRETTY_NAME="CentOS Linux 7 (Core)"
```

### Other than CentOS 7 (e.g. a laptop)

You need docker to run a CentOS 7 container.
Check that you have docker installed and usable

```sh
docker run --rm -it hello-world
# or
sudo docker run --rm -it hello-world
```

If not, go to [setup-docker].

_TODO: OSX caveats? Windows??_

## CVMFS

Check that you have the following CVMFS directories accessible:

```sh
ls -ld /cvmfs/lhcb.cern.ch /cvmfs/lhcbdev.cern.ch /cvmfs/sft.cern.ch
```

If not, go to [setup-cvmfs].

## Git

Check that you have at least `git 2.13`

```sh
git --version
```

If not, the simplest solution is to define the alias

```sh
alias git=/cvmfs/lhcb.cern.ch/lib/contrib/git/2.14.2/bin/git
```
