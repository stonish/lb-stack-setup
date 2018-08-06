# Tools to set up and build the code for Upgrade Hackathon

This project contains a handful of tools and scripts that allow easy checkout
and build of the baseline code for the upgrade targeted hackathon taking place
at the 7th LHCb Computing Workshop.

## Prerequisites
* Docker: you should be able to run Docker containers
* CVMFS: you should have access to /cvmfs/lhcb.cern.ch

If you cannot get Docker or CVMFS running (or you are on a Mac), you can use
the CernVM-based approach described later in the page.

## Quick start
To get started, get the tools with
```
git clone https://gitlab.cern.ch/lhcb/upgrade-hackathon-setup.git hackathon
```
Then from the `hackathon` directory just created invoke
```
./lb-docker-run
```
which will pull the latest image of the SLC6 Docker image we use to build our
software and start an interactive shell in the special directory `/workspace`,
mapped to the directory `hackathon`. *Note*: you may find the options `--home`
and `--ssh-agent` very useful.

Building the whole stack the first time may take a lot of time, so you can
optionally get a prebuilt image with
```
make pull-build
```

At this point you can build the software stack with (will build automatically
in parallel)
```
make
```
Note that if you didn't pull the prebuilt image, this command will checkout the
code and build from scratch.

## Running without docker
It is also possible to run the same code within CernVM.

Follow instructions from:
https://cernvm.cern.ch/portal/vbinstallation

Running the VM specifying the context in CernVM online is probably the simplest option.
(You can also run CernVM in an Openstack as per https://cernvm.cern.ch/portal/openstack)

Once the machine is up and running, you need either ccache or ccache-swig (the
first is slightly better). If you do not have any of them, you can install ccache
with:
```
sudo yum-config-manager --add-repo=http://linuxsoft.cern.ch/epel/6/x86_64/
sudo rpm --import http://linuxsoft.cern.ch/epel/RPM-GPG-KEY-EPEL-6
sudo yum install ccache
```

And don't forget to load the LHCb environment if not done already:
```
source /cvmfs/lhcb.cern.ch/lib/LbLogin.sh
```

You should now be ready to get the hackathon code in a directory called /workspace:
```
sudo mkdir /workspace
sudo chown $USER /workspace
cd /workspace
git clone https://gitlab.cern.ch/lhcb/upgrade-hackathon-setup.git .
```

As explained in the previous section, you can then download a snapshot of the binaries:
```
make pull-build
```

Or rebuild:
```
make
```

## Running on lxplus
Make sure you have enough space on the working area and you are logged in a slc6-gcc49 machine.
```
cd /afs/cern.ch/work/X/USERNAME/
git clone https://gitlab.cern.ch/lhcb/upgrade-hackathon-setup.git workspace
cd workspace
```

Differently from before you cannot get a pre-build image, just call
```
make
```

Note that sometimes on lxplus builds with ninja are killed because they use too
much the machine (you would get an _internal compiler error_ from gcc).
In that case it could be useful to reduce the number of parallel compilations
with something like
```
make NINJAFLAGS=-j8
```

## Makefile instructions
The `Makefile` provided features a few useful targets:

* basic commands
  * _all_ (or _build_): builds all the projects (this is the default)
  * _checkout_: get the sources
  * _update_: update the projects sources
  * _clean_: run a clean of all packages (keeping the sources)
  * _purge_: similar to _clean_, but remove the cmake temporary files
  * _deep-purge_: similar to _clean_, but remove the sources too
  * _help_: print a list of available targets
  * _use-git-xyz_: change the Git remote url of the checkout out projects,
    with _xyz_ replaces with any of _https_, _ssh_ or _krb5_
  * _for-each CMD="do-something"_: run a command in each project directory
* helpers
  * _pull-build_: get a prebuilt image of all the projects
* special project targets
  * _\<Project\>_: build the required project (with dependencies),
  * _\<Project\>/\<target\>_: build the specified target in the given project,
    for example, to get the list of targets available in Gaudi you can call
    `make Gaudi/help`
  * _\<Project\>-\<action\>_: where _\<action\>_ can be _checkout_, _update_,
    _clean_ or _purge_, triggers the action on the specific project (with
    dependencies where it applies)
* _fast_ targets are available for targets with dependencies, for example
  * _fast/\<Project\>_: same as the target _\<Project\>_, but do not try to
    build the dependencies

## Testing and running
LHCb projects come with several tests that can be run via the standard `ctest`
command from the project build directories
(e.g. `Gaudi/build.$CMTCONFIG`), or via the some helper targets in
the top level Makefile, for example:
```
make Gaudi/test ARGS="-N"
make Gaudi/test ARGS="-R GaudiKernel"
```
where the content of the `ARGS` variable is passed to the `ctest` command line.

The arguments that can be passed to `ctest` can be found with `ctest --help`.
Some examples:

* `-N`: just print the names of the tests
* `-R <regex>`: select tests by regular expression
* `-V`: verbose printout (extra details, command line)


Tests hide the output of the job while it's run, but you can find the `.qmt`
file used for the test and run it through `gaudirun.py`, for example:
```
cd Brunel
make test ARGS="-N -V -R Brunel.2015magdown"
./run gaudirun.py /workspace/Brunel/Rec/Brunel/tests/qmtest/brunel.qms/2015magdown.qmt
```

## Debugging
The projects built here are available only as optimized builds, so some special
actions are needed to be able to debug pieces of code:

* if you are using Docker, make sure you started `lb-docker-run` with the option
  `--privileged`
* add the good version of gdb to the path
  ```
  export PATH=/cvmfs/lhcb.cern.ch/lib/contrib/gdb/7.11/x86_64-slc6-gcc49-opt/bin:$PATH
  ```
* change the configuration of the project containing the code to debug
  ```
  sed -i 's/CMAKE_BUILD_TYPE:STRING=.*/CMAKE_BUILD_TYPE:STRING=Debug/' Project/build.${CMTCONFIG}/CMakeCache.txt
  ```
* rebuild the project
  ```
  make Project
  ```
* run the job through the debugger
  ```
  Project/run gdb --args python $(Project/run which gaudirun.py) my_options.py
  ```

## Examples
### Build a project and run it
To run, for example, Brunel with some option file
```
make Brunel
Brunel/run gaudirun.py my_options.py
```
Note that this sequence works with or without previously checked out sources,
in which case it would clone only the required repositories.

For Mini Brunel, the option file and the input file are available on EOS at `/eos/lhcb/software/MiniBrunel`


## Distributed compilation setup
### Prerequisites
- python3, including the headers. On CentOS:
```
yum install python34 python34-devel
```
### AAA
```
git checkout distcc
git submodule update --init tools/src/distcc
cd tools/src/distcc
git checkout tmp
./autogen.sh
./configure --prefix `pwd`/../..
make install
```
