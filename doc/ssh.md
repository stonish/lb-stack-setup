# SSH config tips

You can find wonderful documentation in the
[OpenSSH Cookbook](https://en.wikibooks.org/wiki/OpenSSH#Cookbook).
In particular, check out

- [Public Key Authentication](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Public_Key_Authentication)
- [Proxies and Jump Hosts](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts)
- [Multiplexing](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing)

Below you have some extracts and specific examples.

## Automatic passwordless login to hosts behind a gateway

If your machine is only reachable through a gateway, you need to use the
`ProxyJump` directive.

Here is an example of a minimal `config` file. It demonstrates two use cases:
a host `cern-machine.cern.ch` in the CERN network (going via `lxtunnel.cern.ch`)
and the `pluscc*` hosts in the LHCb Online network (going via both `lxtunnel.cern.ch`
and then `lbgw.cern.ch`).
It works independently of whether you are in the CERN network or outside.

```ssh
Host cm
    HostName cern-machine.cern.ch

# Aliases for hosts in the LHCb Online network
Host pluscc* swdev*
    HostName %h.lbdaq.cern.ch

# Put before the generic *.cern.ch section
Host lbgw.cern.ch *.lbdaq.cern.ch
    # your LHCb Online username (if different)
    User janedoe

Host *.cern.ch
    # your CERN username
    User jdoe
    GSSAPIAuthentication yes
    GSSAPIDelegateCredentials yes

# Proxy *.lbdaq.cern.ch via lbgw only when not in the LHCb Online network.
# Put section after hostname alias definitions and before lxtunnel proxy.
Match host *.lbdaq.cern.ch !exec "hostname -A | grep -q '.lbdaq.cern.ch '"
    ProxyJump lbgw.cern.ch

# Proxy *.cern.ch (besides lxplus and lxtunnel) via lxtunnel only when not in the CERN network.
# Put section after hostname alias definitions.
Match host *.cern.ch,!lxtunnel*.cern.ch,!lxplus*.cern.ch !exec "hostname -A | grep -q '.cern.ch '"
    ProxyJump lxtunnel.cern.ch
```

Put the lines above in your `~/.ssh/config` on Linux/Mac and `??` on Windows.
Then, get a kerberos ticket, and try to login.

### LHCb Online network

```sh
kinit jdoe@CERN.CH
ssh lbgw.cern.ch
```

If you get a password prompt, hit `Ctrl+C` and let's set up public key authentication.

```sh
ssh-copy-id lbgw.cern.ch
# jdoe@lbgw.cern.ch's password: ******
ssh lbgw.cern.ch
```

### Machines on the CERN network

```sh
kinit jdoe@CERN.CH
ssh cm
```

If you succeed, good, that's it! Either your machine supports login with kerberos credentials (GSSAPI)
or you've already setup public key authentication.

If you get a password prompt, hit `Ctrl+C` and let's set up public key authentication.

```sh
ssh-copy-id cm
# jdoe@cern-machine.cern.ch's password: ******
ssh cm
```

## LXPLUS and known_hosts

LXPLUS is a cluster with a shared host key. To prevent spam in your
`known_hosts` and the occasional warning for key mismatch, add the
following in your ssh `config`.

```sh
Host lxplus*.cern.ch
    StrictHostKeyChecking yes
    HostKeyAlias lxplus
    UserKnownHostsFile ~/.ssh/known_hosts.lxplus
```

The content of `~/.ssh/known_hosts.lxplus` should be just a single line

```sh
lxplus,137.138.*,188.184.*,188.185.* ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPZvfRF+9L7TR3FRPyLFdcsXSZ6RQYJHfOjzzWB94sX0gP34Cgij9p4ukL900sVVvw3LPM5OxxFSNIXGztFYu4o=
```

## Faster time to connect using multiplexing

If there is a host to which you connect often, you can speed up successive connections by using connection multiplexing. For example

```sh
Host vm
    # try to use existing connection or create if not available
    ControlMaster auto
    # path to control socket. Keep it private!
    ControlPath ~/.ssh/controlmasters/%h_%p_%r
    # keep master connection in the background for one day
    ControlPersist 1d
```

Make sure you create the directory, and make it accessible only to you, as anyone with access to the sockets will be able to connect to your machine.

```sh
mkdir -p ~/.ssh/controlmasters
chmod 700 ~/.ssh/controlmasters
```

The recipe above won't work if the file system where `ControlPath` points does not support sockets (e.g. AFS).