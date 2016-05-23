# -*- coding: utf-8 -*-
from LbNightlyTools.Configuration import *

LBPROJECTS = ['Gaudi', 'LHCb', 'Lbcom', 'Rec', 'Phys', 'Stripping',
              'Analysis', 'DaVinci', 'Brunel', 'Hlt', 'Moore']
GITURL = 'https://gitlab.cern.ch/LHCb-SVN-mirrors/%s.git'

projectList = [Project(p, 'future',
                       checkout=('git', {'url': GITURL % p}))
               for p in LBPROJECTS]

lhcb_upgrade = Slot('lhcb-future',
                    desc='Branch for upgrade framework task force integration '
                         '(branch: future, Gaudi from group lhcb)',
                    projects=projectList,
                    platforms=['x86_64-slc6-gcc49-opt',
                               'x86_64-slc6-gcc49-dbg']
                    )

lhcb_upgrade.Gaudi.checkout_opts['url'] = \
        'https://gitlab.cern.ch/lhcb/Gaudi.git'

lhcb_upgrade.warning_exceptions = [r'/Boost/',
                                   r'pyconfig\.h']
lhcb_upgrade.env = [
    ('CMAKE_PREFIX_PATH=/afs/cern.ch/lhcb/software/DEV/nightlies' +
        ':${CMAKE_PREFIX_PATH}')
]
