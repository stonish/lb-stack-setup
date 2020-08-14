#!/usr/bin/env python3
from __future__ import print_function
import os
import re
from collections import defaultdict
from config import read_config
from utils import setup_logging, run, DEVNULL

SSH_CONFIG = os.path.join(os.path.dirname(__file__), 'ssh_config')
KNOWN_HOSTS = os.path.join(os.path.dirname(__file__), '.known_hosts')
config = read_config()

log = setup_logging(config['outputPath'])


def parse_spec(spec):
    m = re.match(
        r'^(?P<hostid>[a-zA-Z0-9-.]+)(:(?P<port>[0-9]+))?'
        r'(/(?P<limit>[0-9]+))?(,(?P<options>[^ ]+))?$', spec)
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


def reachable(host, port=None):
    if port is not None:
        code = run(['nc', '--send-only', '--wait', '0.2', host,
                    str(port)],
                   check=False).returncode
    else:
        code = run(['timeout', '0.2', 'ping', '-c1', '-q', host],
                   check=False).returncode
    return code == 0


def have_valid_ticket():
    try:
        return have_valid_ticket.cache
    except AttributeError:
        code = run(['klist', '-s'], check=False).returncode
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
    if reachable(spec['hostid']):
        # The host is directly reachable
        found_hosts.append(host['spec'])
    else:
        # The host needs to be proxied
        new_spec = {
            # "localhost" has a special meaning for distcc -> use "127.0.0.1"
            'hostid':
            '127.0.0.1',
            'port':
            host['localPort'],
            'limit':
            spec['limit'],
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
                (write_spec(new_spec), host['spec'], host['localPort'],
                 spec['hostid'], spec['port']))

if proxied_hosts:
    kerberos_user = run(
        "klist | grep -oP 'Default principal: \K.+(?=@)'",
        shell=True).stdout.strip()

for gateway, hosts in proxied_hosts.items():
    log.info('Starting ssh port forwarding for distcc hosts {}...'.format(
        ' '.join(h[1] for h in hosts)))
    forwards = sum((['-L', '{}:{}:{}'.format(local, host, port)]
                    for _, _, local, host, port in hosts), [])
    cmd = [
        'ssh', '-f', '-N', '-F', SSH_CONFIG, '-o', 'BatchMode=yes', '-o',
        'ExitOnForwardFailure=yes', '-o', 'UserKnownHostsFile=' + KNOWN_HOSTS,
        '-o', 'LogLevel=ERROR'
    ] + forwards + ['{}@{}'.format(kerberos_user, gateway)]
    code = run(
        cmd,
        # decouple stdout so that bash (the command substitution) does
        # not wait forever for the stdout of this process
        stdout=DEVNULL,
        # do not try to capture stderr (for the log) as .communicate()
        # seems hang in that case
        capture_stderr=False,
        check=False).returncode
    if code == 0:
        found_hosts.extend(h[0] for h in hosts)
        log.info('...done.')
    else:
        log.error('Failed to forward ports.'.format(gateway))

found_hosts.sort()
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
print('export DISTCC_IO_TIMEOUT=300')

# TODO add cpp conditionally on USE_DISTCC_PUMP? Does non-pump work now?
# TODO what if you're compiling from one of the distcc hosts?
