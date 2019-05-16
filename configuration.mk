# Configuration for LHCb stack build
# ===================================================================
#
# The known variables are:
# - PROJECTS:
#     A list of projects to build.
#     If a branch (or tag) is optionally specified with Project/branch, it
#     will override the DEFAULT_BRANCH and Project_BRANCH. For example:
#         PROJECTS = Gaudi/v28r1 LHCb Lbcom Rec ...
# - DEFAULT_BRANCH:
#     Default branch to checkout for all projects.
# - Project_BRANCH:
#     branch/tag to checkout for Project, overrides DEFAULT_BRANCH
# - GIT_BASE:
#     git repository base URL, default is https://gitlab.cern.ch
#     If you change this, call "make set-git-remote-url" to apply the change
# - Project_GITGROUP:
#     GitLab group to use for finding the repository.
#     The URL is $(GIT_BASE)/$(Project_GITGROUP)/Project.git
# - Project_URL:
#     Override the default URL based on GIT_BASE and Project_GITGROUP.
# - Project_DEPS:
#     Project dependencies. Modification is normally not needed. If a project
#     is not in PROJECTS, the variable is ignored.

PROJECTS = Gaudi LHCb Lbcom Rec Brunel Phys Moore 
           #Stripping Analysis DaVinci LHCbIntegrationTests
DEFAULT_BRANCH = master
GIT_BASE = ssh://git@gitlab.cern.ch:7999

Gaudi_GITGROUP = gaudi

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
LHCbIntegrationTests_DEPS = Brunel DaVinci Moore
