# SSH config tips

You can find wonderful documentation in the
[OpenSSH Cookbook](https://en.wikibooks.org/wiki/OpenSSH#Cookbook).
In particular, check out

- [Public Key Authentication](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Public_Key_Authentication)
- [Proxies and Jump Hosts](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Proxies_and_Jump_Hosts)
- [Multiplexing](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing)

Below you have some extracts and specific examples.

## Automatic jump proxy to hosts inside the CERN network

```sh
Host lxplus
    HostName lxplus.cern.ch
    User jdoe
    GSSAPIDelegateCredentials yes
    # - you might need to uncomment the following line
    # GSSAPITrustDNS yes

Host vm
    HostName my-openstack-vm.cern.ch
    User jdoe
    GSSAPIDelegateCredentials yes

# use a proxy only when no direct connection possible
# (put section after short hostname definitions)
Match host !lxplus*.cern.ch,*.cern.ch exec "! nc --send-only --wait 0.1 %h %p </dev/null 2>/dev/null"
    ProxyJump lxplus
    # - use ProxyCommand instead of ProxyJump with OpenSSH older than 7.3
    # ProxyCommand ssh lxplus -W %h:%p

Host *
    GSSAPIAuthentication yes
    # - disable public key authentication with
    # PubkeyAuthentication no
    # - disable password prompts with
    # BatchMode yes
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