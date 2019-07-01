#!/usr/bin/python
from __future__ import print_function
import logging
import os
import re
import subprocess
from collections import defaultdict
from config import read_config

SSH_CONFIG = os.path.join(os.path.dirname(__file__), 'ssh_config')
config = read_config()


# set up logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s.%(msecs)03d %(name)-15s %(levelname)-8s %(message)s',
    datefmt='%Y-%m-%dT%H:%M:%S',
    filename=os.path.join(config['outputPath'], 'log'),
    filemode='a')
console = logging.StreamHandler()
console.setLevel(logging.INFO)
console.setFormatter(
    logging.Formatter('%(levelname)-8s %(message)s'))
logging.getLogger('').addHandler(console)
log = logging.getLogger(os.path.basename(__file__))


def run(command):
    log.debug('command: ' + repr(command))
    code = subprocess.call(command, shell=True)
    log.debug('retcode: ' + str(code))
    return code


def parse_spec(spec):
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
    code = run('nc --send-only --wait 0.2 {} {} </dev/null 2>/dev/null'
                     .format(host, port))
    return code == 0


def have_valid_ticket():
    try:
        return have_valid_ticket.cache
    except AttributeError:
        code = run('klist -s')
        have_valid_ticket.cache = code == 0
        return have_valid_ticket.cache


found_hosts = []
proxied_hosts = defaultdict(list)
for host in config['distccHosts']:
    spec = parse_spec(host['spec'])
    if 'auth' in spec['options']:
        if not have_valid_ticket():
            log.warning('No valid kerberos ticket, disabling distcc host ' +
                        host['spec'])
            continue
    if reachable(spec['hostid'], spec['port']):
        # The host is directly reachable
        found_hosts.append(host['spec'])
    else:
        # The host needs to be proxied
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
                (write_spec(new_spec), host['spec'], host['localPort'], spec['hostid'],
                 spec['port'])
            )

for gateway, hosts in proxied_hosts.items():
    log.info('Starting ssh port forwarding for distcc hosts ' +
             ' '.join(h[1] for h in hosts))
    forwards = ' '.join(['-L {}:{}:{}'.format(local, host, port)
                        for _, _, local, host, port in hosts])
    cmd = ('ssh -f -N -F "{}" '
           '-o BatchMode=yes '
           '-o ExitOnForwardFailure=yes '
           '-o UserKnownHostsFile=.known_hosts '
           '-o LogLevel=ERROR '
           '{} {} >/dev/null'
           .format(SSH_CONFIG, forwards, gateway))
    code = run(cmd)
    if code == 0:
        found_hosts.extend(h[0] for h in hosts)
    else:
        log.error('Failed to forward ports. Make sure passwordless login to '
                  '{} works'.format(gateway))

if not found_hosts:
    log.error("No distcc hosts found!")
    exit(1)

# Specify how many jobs that cannot be run remotely can be run concurrently
# on the local machine
n_localslots = config['distccLocalslots']
found_hosts.append('--localslots={}'.format(n_localslots))
# Specify how many preprocessors will run in parallel on the local machine.
# (only relevant for non-pump mode)
n_localslots_cpp = config['distccLocalslotsCpp']
found_hosts.append('--localslots_cpp={}'.format(n_localslots_cpp))

if config['distccRandomize']:
    found_hosts.append('--randomize')

print('export DISTCC_HOSTS="{}"'.format(' '.join(found_hosts)))
print('export DISTCC_PRINCIPAL="{}"'.format(config['distccPrincipal']))
print('export DISTCC_SKIP_LOCAL_RETRY=1')

# TODO add cpp conditionally on USE_DISTCC_PUMP? Does non-pump work now?
