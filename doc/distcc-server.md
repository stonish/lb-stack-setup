# Install distcc server

These are instructions for installing a distcc server on a CentOS 7 machine.
Execute all commands with sudo, or just become root with `sudo su`.

## Install distcc-server from source with GSSAPI authentication support

First remove previously installed packages with `sudo yum remove "distcc*"`.

```sh
cd $HOME/build
git clone https://github.com/rmatev/distcc.git --branch v3.4.20220429 distcc-3.4.20220429
cd distcc-3.4.20220429
./autogen.sh
./configure --with-auth --without-libiberty --without-avahi
make
make check
./distccd --version
# Run individual tests with:
#     PATH=$PWD:$PATH test/onetest.py --pump Gdb_Case

# manually install the minimum possible
sudo install -c distccd /usr/local/bin
```

## Service configuration

Create a system user and group called `distcc`.

```sh
useradd --system --user-group distcc
```

Create a log file with correct owner and permissions and setup log rotation.

```sh
(
    log=/var/log/distccd.log
    touch $log && chown distcc:distcc $log && chmod 0644 $log
    cat >/etc/logrotate.d/distccd <<EOF
$log {
    size 100M
    rotate 5
    missingok
}
EOF
    # logrotate uses crontab, so changes take effect from next run
    cat >/etc/rsyslog.d/distccd.conf <<EOF
if \$programname == 'distccd' then $log
EOF
    systemctl restart rsyslog  # rsyslog needs restarting...
)
```

Open the firewall for port 3632, which is the default port used by `distccd`.

```sh
firewall-cmd --permanent --add-port 3632/tcp
systemctl reload firewalld
```

Write the environment configuration in the file pointed to by the systemd unit
(`systemctl show distccd | grep EnvironmentFile`)

```sh
cat >/etc/sysconfig/distccd <<EOF
DISTCC_CMDLIST=/etc/distcc/commands.allow
DISTCC_CMDLIST_NUMWORDS=1
DISTCCD_PATH=
TMPDIR=/run/distccd
OPTIONS="--allow 0.0.0.0/0 --auth --whitelist /etc/distcc/whitelist"
# only needed for kerberos auth:
DISTCCD_PRINCIPAL="distccd@$(hostname --fqdn)"
KRB5_KTNAME=/etc/krb5.keytab.distccd
EOF
```

Finally, write the service file (adjust the path to `distccd`).

```sh
cat >/usr/lib/systemd/system/distccd.service <<EOF
[Unit]
Description=Distccd A Distributed Compilation Server
After=network.target

[Service]
User=distcc
RuntimeDirectory=distccd
EnvironmentFile=-/etc/sysconfig/distccd
ExecStart=/usr/local/bin/distccd --no-detach --daemon \$OPTIONS

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
```

### Install compiler wrappers

New compiler wrappers are needed about once per year so we set up a daily cron job.

**TODO**: do not download the script every time since it's a security issue.

```sh
mkdir -p /usr/lib/distcc/bin
curl https://gitlab.cern.ch/rmatev/lb-stack-setup/-/raw/master/create_distcc_wrappers.py | python3 - /usr/lib/distcc/bin
ls -1 /cvmfs/lhcb.cern.ch/lib/bin/x86_64-centos7/lcg-* /usr/lib/distcc/bin/* > /etc/distcc/commands.allow

systemctl restart distccd.service
EOF
chmod +x /etc/cron.daily/distcc_config
/etc/cron.daily/distcc_config
```

### Create a whitelist of users that have access (kerberos auth)

The whitelist is a file containing CERN usernames, one on each line.
The file is located at `/etc/distcc/whitelist`.

To add everyone in, e.g. `lhcb-general` and `z5` (people can have more than one
accounts), you can do

```sh
yum install -y openldap-clients  # for ldapsearch

cat >/etc/cron.daily/distcc_config <<'EOF'
ldapsearch -E pr=100/noprompt -x -h xldap.cern.ch -b 'OU=Users,OU=Organic Units,DC=cern,DC=ch' '(&(objectClass=user)(|(gidNumber=1470)(memberof=CN=lhcb-general-dynamic,OU=e-groups,OU=Workgroups,DC=cern,DC=ch)))' sAMAccountName | grep '^sAMAccountName:' | cut -d " " -f 2 | sort > /etc/distcc/whitelist
```

## Setup Kerberos authentication

### Create a service principal for distcc

Create a keytab file for distccd, which registers it in CERN's
central database (KDC).

```sh
cern-get-keytab --service distccd --isolate
chown distcc:distcc /etc/krb5.keytab.distccd
k5srvutil -f /etc/krb5.keytab.distccd list
```

### Test authentication with port forwarding

```sh
ssh -4 -f -N -o ExitOnForwardFailure=yes -L 12345:lbquantaperf02.cern.ch:3632 lxplus.cern.ch
echo 'int main() { return 0; }' >test.cpp
rm -rf ~/.distcc/
DISTCC_PRINCIPAL=distccd DISTCC_HOSTS="127.0.0.1:12345/1,auth=lbquantaperf02.cern.ch --localslots=1" DISTCC_VERBOSE=1 \
    contrib/bin/distcc -o test.o -c test.cpp
```

## Start the service

Enable the service such that it starts on reboot and start it immediatelly.

```sh
systemctl enable distccd
systemctl restart distccd
```

Check for issues with

```sh
systemctl status distccd
journalctl -u distccd -r  # recent messages
journalctl -u distccd -f  # follow messages
```

## Debugging the server interactively

Clone and build.

```sh
git clone https://github.com/distcc/distcc.git
cd distcc
bash -c "
. /cvmfs/sft.cern.ch/lcg/views/LCG_97apython3/x86_64-centos7-gcc9-opt/setup.sh
./autogen.sh
./configure --with-auth --without-libiberty
make
make check
"
```

```sh
id -un > whitelist
rm -f start.sh
cat >start.sh <<EOF
set -euxo pipefail
export DISTCCD_PATH=/cvmfs/lhcb.cern.ch/lib/bin/x86_64-centos7:/usr/bin
export DISTCCD_PRINCIPAL="distccd@$(hostname --fqdn)"
export KRB5_KTNAME=/etc/krb5.keytab.distccd
export DISTCC_SAVE_TEMPS=1
export TMPDIR=/tmp/distccd
mkdir -p \$TMPDIR
distccd --allow 0.0.0.0/0 --auth --whitelist $(realpath whitelist) \
  --stats --stats-port 5505 \
  --jobs 1 --log-level=debug --no-detach --log-stderr --daemon
EOF

sudo -u distcc bash start.sh
```
