DEFAULT_BRANCH = future
PROJECTS = Gaudi LHCb Lbcom Rec Phys Stripping Analysis DaVinci Brunel Hlt # Moore

# FIXME: it would be nice to generate the dependencies
LHCb_DEPS = Gaudi
Lbcom_DEPS = LHCb
Rec_DEPS = Lbcom
Phys_DEPS = Rec
Analysis_DEPS = Phys
Stripping_DEPS = Phys
Hlt_DEPS = Phys

Brunel_DEPS = Rec
DaVinci_DEPS = Analysis Stripping
Moore_DEPS = Hlt

# compute inverse deps for "clean" targets
$(foreach p,${PROJECTS},$(foreach d,${${p}_DEPS},$(eval ${d}_INV_DEPS += ${p})))
