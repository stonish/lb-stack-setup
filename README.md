# Tools to set up and build the code for Upgrade Hackaton at 7th LHCb Computing Workshop

This project contains a handful of tools and scripts that allow easy checkout
and build of the baseline code for the upgrade targeted hackaton taking place
at the 7th LHCb Computing Workshop.

## Prerequisites
* Docker: you should be able to run Docker containers
* CVMFS: you should have access to /cvmfs/lhcb.cern.ch

## Quick start
To get started, get the tools with
```
git clone https://gitlab.cern.ch/lhcb/upgrade-hackaton-setup.git hackaton
```
Then from the `hackaton` directory just created invoke
```
./lb-docker-run
```
which will pull the latest image of the SLC6 Docker image we use to build our
software and start an interactive shell in the special directory `/workspace`,
mapped to the directory `hackaton`.

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

And don't forget to load the LHCb environment if not down already:
```
source /cvmfs/lhcb.cern.ch/lib/LbLogin.sh
```
 
You should now be ready to get the hackathon code in a directory called /workspace:
```
sudo mkdir /workspace
sudo chown <youruser> /workspace
cd /workspace
git clone https://gitlab.cern.ch/lhcb/upgrade-hackaton-setup.git .
``` 

As explained in the previous section, you can then download a snapshot of the binaries:
```
make pull-build
```

Or rebuild:
```
make
```
