# Install distcc server

These are instructions for installing a distcc server on a CentOS 7 machine.
Execute all commands with sudo, or just become root with `sudo su`.

## Install distcc-server with GSSAPI authentication support

Add the CERN repo that has `distccd` compiled with GSSAPI authentication support.

```sh
cat >/etc/yum.repos.d/distcc7-stable.repo <<'EOF'
[distcc7-stable]
name=distcc cern version (krb enabled) [stable] (OS)
baseurl=http://linuxsoft.cern.ch/internal/repos/distcc7-stable/x86_64/os
enabled=1
gpgcheck=0
priority=5
EOF
```

Install the `distcc-server` package, which provides `distccd`.

```sh
yum install -y distcc-server
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


### Create a whitelist of users that have access

The whitelist is a file containing CERN usernames, one on each line.
The file is located at `/etc/distcc/whitelist`.

To add everyone in, e.g. `lhcb-general` and `z5` (people can have more than one
accounts), you can do

```sh
yum install -y openldap-clients  # for ldapsearch
ldapsearch -E pr=100/noprompt -x -h xldap.cern.ch -b 'OU=Users,OU=Organic Units,DC=cern,DC=ch' '(&(objectClass=user)(|(gidNumber=1470)(memberof=CN=lhcb-general-dynamic,OU=e-groups,OU=Workgroups,DC=cern,DC=ch)))' sAMAccountName | grep '^sAMAccountName:' | cut -d " " -f 2 | sort > /etc/distcc/whitelist
```

## Service configuration

Create a system user and group called `distcc`.

```sh
useradd --system --user-group distcc
```

Tell the distcc service to use the new user.

```sh
mkdir -p /etc/systemd/system/distccd.service.d
echo -e "[Service]\nUser=distcc" | sudo tee /etc/systemd/system/distccd.service.d/10-user.conf
systemctl daemon-reload
```

Create a log file with correct owner and permissions and setup log rotation.

```sh
(
    log=/var/log/distccd.log
    touch $log && chown distcc:distcc $log && chmod 0644 $log
    cat >/etc/logrotate.d/distccd <<EOF
# logrotate.d configuration for distcc
$log {
    missingok
    copytruncate
    notifempty
    rotate 3
    minsize 100M
}
EOF
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
#DISTCC_CMDLIST=/etc/distcc/commands.allow
#DISTCC_CMDLIST_NUMWORDS=1
DISTCCD_PATH=/cvmfs/lhcb.cern.ch/lib/bin/x86_64-centos7:/usr/bin
# TODO ^ needed if full path to lcg-*?
DISTCCD_PRINCIPAL="distccd@$(hostname --fqdn)"
KRB5_KTNAME=/etc/krb5.keytab.distccd
OPTIONS="--log-file /var/log/distccd.log --allow 0.0.0.0/0 --auth --whitelist /etc/distcc/whitelist"
EOF
```

## Start the service

Enable the service such that it starts on reboot and start it immediatelly.

```sh
systemctl enable distccd
systemctl start distccd
```

Check for issues with

```sh
systemctl status distccd
```
