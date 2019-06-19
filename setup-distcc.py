#!/usr/bin/env python
from __future__ import print_function
import multiprocessing
import os
import re
import sys
from collections import defaultdict
from config import read_config

SSH_CONFIG = os.path.join(os.path.dirname(__file__), 'ssh_config')
config = read_config()


def parse_spec(spec):
    # FIXME: matches only HOSTID[:PORT][/LIMIT][OPTIONS] for now
    m = re.match(r'^(?P<hostid>[a-zA-Z0-9-.]+)(:(?P<port>[0-9]+))?'
                 r'(/(?P<limit>[0-9]+))?(,(?P<options>[^ ]+))?$',
                 spec)
    if not m:
        raise ValueError('Cannot parse HOSTSPEC {!r}'.format(spec))
    spec = m.groupdict()
    spec['port'] = int(spec['port'] or 3632)
    spec['limit'] = int(spec['limit'] or 4)
    spec['options'] = (spec['options'] or '').split(',')
    return spec


def write_spec(spec):
    s = '{hostid}:{port}/{limit}'.format(**spec)
    return s if not spec['options'] else (s + ',' + ','.join(spec['options']))


def reachable(host, port):
    code = os.system('nc --send-only --wait 0.2 {} {} </dev/null 2>/dev/null'
                     .format(host, port))
    return code == 0


found_hosts = []
proxied_hosts = defaultdict(list)
for host in config['distccHosts']:
    spec = parse_spec(host['spec'])
    if reachable(spec['hostid'], spec['port']):
        found_hosts.append(host['spec'])
    else:
        new_spec = {
            # "localhost" has a special meaning for distcc -> use "127.0.0.1"
            'hostid': '127.0.0.1',
            'port': host['localPort'],
            'limit': spec['limit'],
            'options': [
                opt if opt != 'auth' else ('auth=' + spec['hostid'])
                for opt in spec['options']
            ]
        }
        if reachable(new_spec['hostid'], new_spec['port']):
            found_hosts.append(write_spec(new_spec))
        else:
            # collect hosts to proxy
            proxied_hosts[host['gateway']].append(
                (write_spec(new_spec), host['localPort'], spec['hostid'], spec['port'])
            )

for gateway, hosts in proxied_hosts.items():
    forwards = ' '.join(['-L {}:{}:{}'.format(local, host, port)
                        for _, local, host, port in hosts])
    cmd = ('ssh -f -N -F "{}" -o BatchMode=yes -o ExitOnForwardFailure=yes {} {}'
           .format(SSH_CONFIG, forwards, gateway))
    # TODO use logging
    print(cmd, file=sys.stderr)
    code = os.system(cmd)
    if code == 0:
        found_hosts.extend(h[0] for h in hosts)
    else:
        # TODO use logging
        print('Failed to forward ports. Make sure passwordless login to {} works'
              .format(gateway),
              file=sys.stderr)

# Specify how many jobs that cannot be run remotely can be run concurrently
# on the local machine
n_localslots = config['distccLocalslots']
if n_localslots <= 0:
    n_localslots = multiprocessing.cpu_count()
found_hosts.append('--localslots={}'.format(n_localslots))
# Specify how many preprocessors will run in parallel on the local machine.
# (only relevant for non-pump mode)
n_localslots_cpp = config['distccLocalslotsCpp']
if n_localslots_cpp <= 0:
    n_localslots_cpp = n_localslots * 2
found_hosts.append('--localslots_cpp={}'.format(n_localslots_cpp))

if config['distccRandomize']:
    found_hosts.append('--randomize')

print('export DISTCC_HOSTS="{}"'.format(' '.join(found_hosts)))
print('export DISTCC_PRINCIPAL="{}"'.format(config['distccPrincipal']))
print('export DISTCC_SKIP_LOCAL_RETRY=1')

# TODO add cpp conditionally on USE_DISTCC_PUMP? Does non-pump work now?
