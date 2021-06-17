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

The following features are supported for both C++ and Python.

- [Intellisense](https://code.visualstudio.com/docs/editor/intellisense)
  support, e.g. code completion, parameter info, quick info, member lists.
- [Code navigation](https://code.visualstudio.com/docs/editor/editingevolved),
  e.g. "Go to Definition" across projects from the stack.
  - __WARNING__: Following public headers leads you to `InstallArea/...`.
    Any modifications in installed files will be overwritten on the next `make`.
  - Following Python imports always leads to sources (except for generated modules).
- Formatting with the LHCb styles with `Ctrl(Cmd)+Shift+I` (Format Document).
  - Automatic formatting can be enabled with the `editor.formatOnSave` setting.

> __Note:__ these features have only been tested in a setup where
> VSCode is installed on a Linux desktop and the stack workspace resides
> on a CentOS 7 machine, which is accessed with the Remote - SSH extension.

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

The Remote - SSH extension requires that you define a host in your
ssh `config` file. A convenient way to to do it is described at
[ssh.md](ssh.md). For more related tips and tricks see the
[official docs](https://code.visualstudio.com/docs/remote/troubleshooting).

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
