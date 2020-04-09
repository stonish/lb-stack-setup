# Visual Studio Code integration

## Get started

Go to [code.visualstudio.com](https://code.visualstudio.com) and check out
the installation instructions for VS Code.
They should be straightforward to follow.

VS Code has an excellent [documentation](https://code.visualstudio.com/docs),
particularly helpful if you get stuck or you just want to explore the available
features.

### Remote Development extension

- [Announcement blog post](https://code.visualstudio.com/blogs/2019/05/02/remote-development)
- [Remote Development extension pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)
- [Remote - SSH extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
- Official documentation:
  - [Overview](https://code.visualstudio.com/docs/remote/remote-overview)
  - [SSH](https://code.visualstudio.com/docs/remote/ssh)
  - [Trobleshooting](https://code.visualstudio.com/docs/remote/troubleshooting)
  - [Linux prerequisites](https://code.visualstudio.com/docs/remote/linux)
  - [FAQ](https://code.visualstudio.com/docs/remote/faq)

### Live Share extension

- [Announcement blog post](https://code.visualstudio.com/blogs/2017/11/15/live-share)
- [Live Share extension](https://marketplace.visualstudio.com/items?itemName=MS-vsliveshare.vsliveshare)
- Documentation
  - [Overview](https://docs.microsoft.com/en-us/visualstudio/liveshare/)
  - [VS Code](https://docs.microsoft.com/en-us/visualstudio/liveshare/use/vscode)

## LHCb integration

### Supported features

- C++ intellisense
  - support accross projects from the stack
  - __WARNING__: following public headers leads you to `InstallArea/...`. Any modifications in installed files will be overwritten on the next `make`.
- Python intellisense
  - support accross projects from the stack
  - following imports always leads to sources (execpt for generated modules)

### Desired features

We need an extension that allows us to

- switch platform
- build/install/purge a project
- build a projects and its dependencies
- run all tests of a project
- run a single test
- run a single test with debugger

## Tips and tricks

### Proxied passwordless login

The `Remote - SSH` extension requires that you define a host in your
ssh `config` file.
If the host is only reachable through a gateway, you need to use the
`ProxyJump` directive.

Here is an example of a minimal `config` file, in the case where you want to
reach a (virtual) machine `my-openstack-vm.cern.ch` in the CERN network, and
you need to go via `lxplus`.
It works independently of whether you are in the CERN network or outside.

```ssh_config
Host lxplus
    HostName lxplus.cern.ch
    User jdoe
    GSSAPIDelegateCredentials yes
    GSSAPIAuthentication yes

Host vm
    HostName my-openstack-vm.cern.ch
    User jdoe
    GSSAPIDelegateCredentials yes
    GSSAPIAuthentication yes

Match host !lxplus*.cern.ch,*.cern.ch exec "! nc --send-only --wait 0.1 %h %p </dev/null 2>/dev/null"
    ProxyJump lxplus
```

Put the lines above in your `~/.ssh/config` on Linux/Mac and `??` on Windows.
Then, get a kerberos ticket, and try to login.

```sh
kinit jdoe@CERN.CH
ssh vm
```

If you succeed, good, that's it! Either your machine supports login with kerberos credentials (GSSAPI) or you've already setup public key authentication.

If you get a password prompt, hit `Ctrl+C` and let's set up public key authentication.

```sh
cat ~/.ssh/id_rsa.pub | ssh vm \
    "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
# jdoe@my-openstack-vm.cern.ch's password: ******
ssh vm
```

If any of the above does not work for you, or you want to learn more,
check the tips in [ssh.md](ssh.md).

### Open a remote workspace/folder from the command line

The VS Code command line interface (CLI) allows to conveniently start
a new window, directly connecting to a remote workspace.
If your SSH host is called `vm`, then the magic command is

```sh
code --file-uri "vscode-remote://ssh-remote+vm/home/jdoe/stack/stack.code-workspace"
```

If you want to open a folder, the syntax is

```sh
code --folder-uri "vscode-remote://ssh-remote+vm/home/jdoe/some/folder"
```

Now go ahead and make an alias for your favourite workspace :sunglasses:.

### Local test dashboard
1. Install the [Live Server](https://marketplace.visualstudio.com/items?itemName=ritwickdey.LiveServer) extension.
2. Start the server: `Ctrl+Shift+P` -> `Live Server: Open with Live Server`, select a workspace when prompted. The port is `5500` by default.
3. If using Remote, forward the port: `Ctrl+Shift+P` -> `Forward a Port` (use the port from above).
4. Open the local port, e.g. [http://localhost:5500]() and navigate to the test results, e.g. [http://localhost:5500/build.x86_64-centos7-gcc9-opt/html/]().
5. To change project, use the `Live Server: Change Live Server workspace` command.
