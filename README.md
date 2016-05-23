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
git clone https://gitlab.cern.ch/clemenci/upgrade-hackaton-setup.git hackaton
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

At this point you can build the software stack with (tune the number of parallel
jobs according to your machine)
```
make -j 4
```
Note that if you didn't pull the prebuilt image, this command will checkout the
code and build from scratch.
