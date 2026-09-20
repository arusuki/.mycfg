# Cross-platform Setup

English | [简体中文](README_zh.md)

The configuration is managed through the bare Git repository at `~/.mycfg`, with `$HOME` as
the working tree and the `config` shell function as its interface.
After `config pull`, whether it succeeds or fails, the function runs `submodule sync --recursive`
and `submodule update --init --recursive` to synchronize submodule URLs and check out the
submodule revisions recorded in the main repository. Other commands are forwarded to Git
with their original arguments. If pull fails, its exit code is preserved; if pull succeeds
but submodule synchronization fails, the function returns a nonzero exit code.

## Usage

If the configuration is already in place, install packages for the current platform only:

```sh
bash ~/scripts/install_packages.sh
```

For a full setup, including Git submodules and tmux plugins:

```sh
bash ~/scripts/bootstrap.sh
```

For a first-time installation, download `bootstrap.sh` and run it with Bash. The script clones
the repository and checks out the configuration if `~/.mycfg` does not exist.
If existing configuration files cause checkout conflicts, back them up and resolve the
conflicts yourself; the script does not force overwrites.
Bootstrap automatically adds `source "$HOME/scripts/init_zsh.sh"` to `${ZDOTDIR:-$HOME}/.zshrc`
unless a loading line already exists. Open a new Zsh session after installation.

## Platform-specific Maintenance

| Platform | Installation script | Package manifest |
| --- | --- | --- |
| Linux | `scripts/linux/install.sh` | `scripts/linux/aqua.yaml` |
| macOS | `scripts/macos/install.sh` | `scripts/macos/Brewfile` |

The shared entry point selects the platform using `uname -s` and exits with an error on
unsupported systems.
The default packages are Node.js, fd, fzf, ripgrep, Neovim, tree-sitter CLI, and tmux; macOS
also installs zsh. Node.js is retained for npm tools installed by Mason. Python is not
installed by default, and uv is optional.
pynvim, mise, and the old remote plugin registration steps have been removed.

On Linux, install Git, curl, Bash, tar, sha256sum, a C/C++ compiler, make, and zsh beforehand
using your distribution's package manager. tmux is installed through aqua's `tmux/tmux-builds`
package using upstream prebuilt binaries for Linux x86_64 and ARM64, so no separate
compilation is required.
aqua is installed if missing. Its default version is pinned in `linux/install.sh`;
`AQUA_VERSION` can override the version used for the initial installation.
aqua uses a manifest with pinned package versions, and `env.sh` configures the environment.
The global configuration keeps tools available outside `$HOME`.
Existing `AQUA_ROOT_DIR`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and other `AQUA_GLOBAL_CONFIG`
entries are preserved.
On Linux, the global npm installation prefix defaults to
`${XDG_DATA_HOME:-$HOME/.local/share}/npm-global` and can be overridden with `NPM_CONFIG_PREFIX`.

### Linux glibc Compatibility

Linux requires glibc 2.28 or later. Bootstrap checks the version before cloning, checking out
files, or initializing submodules. Standalone package installation and configuration
generation also check the version and exit with an error if it is below 2.28.
During installation, `getconf GNU_LIBC_VERSION` detects glibc, and
`${XDG_CONFIG_HOME:-$HOME/.config}/mycfg/aqua.yaml` is generated from `scripts/linux/aqua.yaml`.
The generated file is shared by the installation script and the shell's `AQUA_GLOBAL_CONFIG`
and is not committed to Git. Versions are maintained only in the source manifest and are
not downgraded for individual machines. Linux x86_64 and ARM64 are supported.
If glibc cannot be detected, is older than 2.28, or the architecture is unsupported, generation
fails and preserves the previously generated configuration.

| Software (currently pinned version) | glibc condition | Installation source |
| --- | --- | --- |
| Neovim 0.12.5 | 2.28 ≤ glibc < 2.34 | [neovim/neovim-releases](https://github.com/neovim/neovim-releases) (glibc 2.17 build) |
| tree-sitter CLI 0.27.0 | 2.28 ≤ glibc < 2.39 | [arusuki/tree-sitter-releases](https://github.com/arusuki/tree-sitter-releases) (glibc 2.17 build) |
| Both packages above | Meets the respective threshold | Upstream builds from the aqua standard registry |

Compatibility packages are defined in the local `mycfg-compat` registry in `linux/registry.yaml`
and retain the original package names. tree-sitter is verified using the release's `SHA256SUMS`.
`env.sh` loads `linux/aqua-policy.yaml` to allow these two compatibility packages while
preserving other `AQUA_POLICY_CONFIG` entries.
When the global configuration is loaded, inherited source manifest entries are replaced so
that new shells do not keep selecting incompatible upstream packages. The uninstall menu
also recognizes the compatibility registry.
After changing systems or updating the manifest, rerun the installation entry point to
select the appropriate builds again. You can also generate the configuration on its own:

```sh
bash ~/scripts/linux/generate-aqua.sh
source ~/scripts/env.sh
```

The ELF symbol requirements of the current releases have been checked: the x86_64 builds
of fd, fzf, ripgrep, tmux, and optional uv do not depend on the system glibc, and all have
been verified to start on glibc 2.31. The x86_64 build of Node.js 24.21.0 requires
glibc >= 2.28, and the ARM64 build of ripgrep 15.2.0 requires glibc >= 2.18. Both meet this
configuration's minimum version requirement. These checks do not cover tools subsequently
downloaded by Mason/npm or Python downloaded by uv, nor do they guarantee compatibility
with older kernels or other system libraries.

### macOS

Install Xcode Command Line Tools first (`xcode-select --install`).
If Homebrew is missing, the official installer is run, followed by `brew bundle install`
to install or upgrade the packages in the manifest.
The environment configuration supports Homebrew on PATH as well as the Apple Silicon
path `/opt/homebrew` and Intel path `/usr/local`.
On both platforms, the package manager provides Neovim, tree-sitter CLI, and tmux.

## Verify the Installation

Run `bash ~/scripts/install_packages.sh`, then open a new Zsh session and check:

```sh
command -v nvim tree-sitter tmux
nvim --version
tree-sitter --version
tmux -V
```

On Linux, commands should resolve to aqua's `bin` directory; on macOS, they should come
from Homebrew.

## Optional uv Installation

In an interactive terminal, `bootstrap.sh` asks whether to install uv; pressing Enter skips
it by default. Noninteractive runs also skip it by default. You can explicitly choose either
option without answering a prompt:

```sh
bash ~/scripts/bootstrap.sh --with-uv
bash ~/scripts/bootstrap.sh --without-uv

# Packages only, including uv.
bash ~/scripts/install_packages.sh --with-uv
```

Linux uses a separate `linux/uv.yaml` manifest and enables its global configuration in the
shell only after installation. On macOS, the Brewfile includes uv according to the current
installation choice.
The choice affects only the current installation and does not modify the package manifests;
skipping uv does not uninstall an existing installation.
To update the uv version on Linux, use `aqua -c ~/scripts/linux/uv.yaml update -p`.
If you need Python, run `uv python install` separately; this does not affect the default
configuration setup.

## Uninstall

```sh
bash ~/scripts/uninstall.sh           # Interactive selection.
bash ~/scripts/uninstall.sh --dry-run
bash ~/scripts/uninstall.sh --keep-uv
```

In the menu, `[x]` means **uninstall**, and `[ ]` means **keep**.
Use the arrow keys or `j` / `k` to move, Space to toggle a selection, Enter to review the
execution list, and `q` to cancel. After reviewing the list, enter `y` to execute it;
dry-run mode prints the commands directly.
The list scrolls with the cursor, and no additional menu tool is required.

- aqua and Homebrew each appear as a root node; both can be present at the same time.
- Selecting a package manager's root node selects and locks all its children and also
  uninstalls the package manager itself. Deselecting the root restores the previous
  selections for individual packages.
- aqua uses `aqua list -a -installed` to list installed packages from the current and global
  configurations. Multiple versions of the same package appear as one entry; uninstalling
  an individual package removes all its installed versions and command links.
- Homebrew lists all installed formulae and casks, including software outside the
  bootstrap manifest.
- By default, package managers are kept, while installed packages from the current
  platform's bootstrap manifest, tmux plugins, and initialized submodules are selected.
  Packages outside the manifest are not selected by default. `--keep-uv` only changes
  the default selection; selecting its root node still forces uv to be selected.
- tmux plugins and Git submodules can also be kept individually or selected together
  through their respective "select all" root nodes.

Selecting the aqua root node deletes the entire aqua data directory, including unlisted
older versions, caches, and built-in managers, honoring `AQUA_ROOT_DIR` / `XDG_DATA_HOME`.
Deletion is refused for overly broad paths or directories not managed by the aqua installer.
If aqua was installed through Homebrew or another package manager, uninstall it through
that package manager.
Selecting the Homebrew root node first uninstalls all casks, then downloads and runs
Homebrew's official uninstaller. This removes the entire Homebrew installation and may
require system privileges. When Homebrew is kept, only selected packages are uninstalled;
dependency checks still apply, and other unselected dependencies are not automatically
removed. Uninstall failures are reported and result in a nonzero exit status.

Noninteractive execution requires an explicit `--yes`, which uses the defaults above
and keeps package managers:

```sh
bash ~/scripts/uninstall.sh --yes --keep-uv
bash ~/scripts/uninstall.sh --dry-run  # Uses defaults without a terminal.
```

When uninstallation is executed, this configuration's standalone loading line is
automatically removed from `${ZDOTDIR:-$HOME}/.zshrc`.
Supported forms include `source` / `.`, `$HOME` / `${HOME}` / `~` / the absolute HOME path,
and common quoting styles. Other configuration, file permissions, and symbolic links are
preserved; canceling or previewing does not modify the file.
Use the same `ZDOTDIR` for bootstrap and uninstall. Rerunning bootstrap restores the
loading line and installation.

The installation scripts do not record whether software was present before bootstrap,
so preexisting software with matching names is also selected by default.
Configuration files, `~/.mycfg`, system dependencies, old mise installations, global npm
packages, Python installations and virtual environments managed by uv, and Neovim data
are preserved. Custom data directories inside a deleted package manager directory are
deleted along with it.
Git refuses to deinitialize submodules with local changes. tmux plugins with modified or
untracked files are kept, and an error is reported.
Submodule Git data is retained in `~/.mycfg/modules`.
The default tmux plugin directory is `~/.tmux/plugins`; pass a custom directory through
`TMUX_PLUGIN_MANAGER_PATH`. Plugins additionally declared in other files or running tmux
sessions must be handled manually.
The current shell and tmux sessions are not terminated. After uninstalling TPM, manually
disable its loading line in the retained `.tmux.conf`.

Command references: [List installed aqua packages](https://aquaproj.github.io/docs/guides/list-installed-packages/),
[Uninstall aqua packages](https://aquaproj.github.io/docs/guides/uninstall-packages/),
[Uninstall aqua](https://aquaproj.github.io/docs/reference/uninstall/),
[Uninstall Homebrew packages](https://docs.brew.sh/Manpage#uninstall-remove-rm-options-installed_formulainstalled_cask-),
and [Homebrew's official uninstaller](https://github.com/Homebrew/install/blob/HEAD/uninstall.sh).

## Update and Stage Changes

To add a package on Linux, use `aqua -c ~/scripts/linux/aqua.yaml generate -i OWNER/REPO`.
Update package versions with `aqua -c ~/scripts/linux/aqua.yaml update -p`; to update only
the registry, replace `-p` with `-r`. Review the manifest diff, then rerun the installation
entry point. On macOS, edit the Brewfile directly.
Do not edit the generated `~/.config/mycfg/aqua.yaml` directly. When updating Neovim or
tree-sitter, confirm that the compatibility repository provides the same tag and recheck
the glibc thresholds in `linux/generate-aqua.sh`.
Offline regression checks: `bash ~/scripts/tests/aqua.sh` (covers version boundaries,
Bash/Zsh environments, and installation entry points).

```sh
config diff -- .gitmodules scripts .config/nvim/init.lua
config add .gitmodules scripts .config/nvim/init.lua
config diff --cached
```

`config` hides untracked files by default, so new scripts must be explicitly added with
`config add`.
Existing mise installations and tools downloaded by mise are not uninstalled, but the
new shell configuration no longer adds mise shims.

References: [aqua global configuration](https://aquaproj.github.io/docs/tutorial/global-config/),
[aqua Node.js configuration](https://aquaproj.github.io/docs/reference/nodejs-support/),
and [Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile).
