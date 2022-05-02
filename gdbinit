set auto-load safe-path /cvmfs/lhcb.cern.ch/lib/lcg/releases

# TODO why is this needed and auto-loading doesn't work with:
# /cvmfs/lhcb.cern.ch/lib/lcg/releases/LCG_101/gcc/11.1.0/x86_64-centos7/lib64/libstdc++.so.6.0.29-gdb.py
#
# https://www.gonwan.com/2014/07/02/setting-up-pretty-printers-in-gdb/
python
import sys
sys.path.append('/cvmfs/lhcb.cern.ch/lib/lcg/releases/LCG_101/gcc/11.1.0/x86_64-centos7/share/gcc-11.1.0/python')
from libstdcxx.v6.printers import register_libstdcxx_printers
register_libstdcxx_printers (None)
end

# In order to step into LCG libraries, you will need to obtain the sources
# locally (make sure to use the right tag) and set up a path substitution
# such as the following
#set substitute-path /build/jenkins/workspace/lcg_release_pipeline/build/projects/ROOT-v6.24.00/src/ROOT/v6.24.00 /home/rmatev/root
#set substitute-path /workspace/build/externals/XercesC-3.2.3/src/XercesC/3.2.3 /home/rmatev/xerces-c
