DEFAULT_BRANCH = master
# PROJECTS = Gaudi LHCb Lbcom Rec Brunel Phys Hlt Moore Stripping Analysis DaVinci
PROJECTS = LHCb Lbcom Rec Brunel Phys Hlt Moore Stripping Analysis DaVinci

# Take Gaudi.git from https://gitlab.cern.ch/gaudi (default: https://gitlab.cern.ch/lhcb)
Gaudi_GITGROUP = gaudi
Gaudi_BRANCH = master

# FIXME: it would be nice to generate the dependencies
LHCb_DEPS = Gaudi
Lbcom_DEPS = LHCb
Rec_DEPS = Lbcom
Brunel_DEPS = Rec
Phys_DEPS = Rec
Hlt_DEPS = Phys
Moore_DEPS = Hlt
Stripping_DEPS = Phys
Analysis_DEPS = Phys
DaVinci_DEPS = Stripping Analysis
