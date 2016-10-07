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

Once the machine is up and running, you need to add ccache to the config:
```
sudo yum-config-manager --add-repo=http://linuxsoft.cern.ch/internal/yumsnapshot/20160518/epel/6/x86_64
sudo yum install --nogpgcheck ccache
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
mkdir workspace
git clone https://gitlab.cern.ch/lhcb/upgrade-hackathon-setup.git .
```
Differently from before you cannot get a pre-build image, so do not run 
```make pull-build``` (NO!)
but simply 
```make```

## Makefile instructions
The `Makefile` provided features a few useful targets:

* basic commands
  * _all_ (or _build_): builds all the projects (this is the default)
  * _checkout_: get the sources
  * _update_: update the projects sources
  * _clean_: run a clean of all packages (keeping the sources)
  * _purge_: similar to _clean_, but remove the cmake temporary files
  * _deep-purge_: similar to _clean_, but remove the sources too
* helpers
  * _pull-build_: get a prebuilt image of all the projects
* access to projects
  * _\<Project\>/\<target\>_: call the specified make target in the given project,
    for example, to get the list of targets available in Gaudi you can call
    `make Gaudi/help`

## Testing and running
LHCb projects come with several tests that can be run via the standard `ctest`
command from the project build directories
(e.g. `GAUDI/GAUDI_future/build.$CMTCONFIG`), or via the some helper targets in
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
cd BRUNEL/BRUNEL_future
make test ARGS="-N -V -R Brunel.2015magdown"
./build.$CMTCONFIG/run gaudirun.py /workspace/BRUNEL/BRUNEL_future/Rec/Brunel/tests/qmtest/brunel.qms/2015magdown.qmt
```



