#!/usr/bin/env python
import re
import signal
import sys
import time
from os import listdir
from os.path import join, dirname, isdir

LOG = join(dirname(__file__), '.heartbeat')


TIMEOUT = 60.  # seconds
STEP = 10.  # seconds

def nforks():
    with open('/proc/stat') as f:
        s = f.read()
        m = re.search('processes (\d+)', s)
        try:
            return int(m.group(1))
        except:
            return 0


def iszombie(pid):
    """Is the process a zombie?"""
    with open(join('/proc', str(pid), 'stat')) as f:
        return f.read().split()[2] == 'Z'


def nprocs():
    """Return the number of non-zombie processes."""
    return sum(p.isdigit() and isdir(join('/proc', p)) and not iszombie(p)
               for p in listdir('/proc'))


# respond to SIGTERM (docker stop)
signal.signal(signal.SIGTERM, sys.exit)

nf, countdown = -1, TIMEOUT
while countdown > 0:
    nf, nf0 = nforks(), nf
    np = nprocs()
    if nf > nf0 or np > 1:
        # new processes were started or something is running, reset countdown
        countdown = TIMEOUT
    with open(LOG, 'a') as f:
        f.write('[{:.1f}] {} {} {}\n'.format(time.time(), nf, np, countdown))
    time.sleep(STEP)
    countdown -= STEP
