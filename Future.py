# -*- coding: utf-8 -*-
from LbNightlyTools.Configuration import *

LBPROJECTS = ['Gaudi', 'LHCb', 'Lbcom', 'Rec', 'Phys', 'Stripping',
              'Analysis', 'DaVinci', 'Brunel', 'Hlt', 'Moore']


def url(name):
    '''Return correct Git URL for a project.'''
    # base = 'ssh://git@gitlab.cern.ch:7999/'
    base = 'https://gitlab.cern.ch/'
    if name in ('Gaudi', 'Hlt', 'Moore'):
        return '%slhcb/%s.git' % (base, name)
    return '%sLHCb-SVN-mirrors/%s.git' % (base, name)


lhcb_upgrade = Slot('lhcb-future',
                    desc='Branch for upgrade framework task force integration '
                         '(branch: future, Gaudi from group lhcb)',
                    projects=[Project(p, 'future',
                                      checkout=('git', {'url': url(p)}))
                              for p in LBPROJECTS],
                    platforms=['x86_64-slc6-gcc49-opt',
                               'x86_64-slc6-gcc49-dbg']
                    )

lhcb_upgrade.Moore.overrides['Hlt/HltCache'] = None

lhcb_upgrade.warning_exceptions = [r'/Boost/',
                                   r'pyconfig\.h']
lhcb_upgrade.env = [
    ('CMAKE_PREFIX_PATH=/afs/cern.ch/lhcb/software/DEV/nightlies' +
        ':${CMAKE_PREFIX_PATH}')
]
