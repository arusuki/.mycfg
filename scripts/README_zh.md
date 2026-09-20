# 跨平台安装

[English](README.md) | 简体中文

配置通过 bare Git 仓库 `~/.mycfg` 管理，工作区是 `$HOME`，通过 `config` shell 函数操作。
`config pull` 无论成功与否，随后都会执行 `submodule sync --recursive` 和
`submodule update --init --recursive`，同步子模块 URL，并检出主仓库记录的子模块版本。
其他命令按原参数转发给 Git。pull 失败时保留其退出码；pull 成功但子模块同步失败时返回非零。

## 使用

已有配置时，仅安装当前平台的软件包：

```sh
bash ~/scripts/install_packages.sh
```

完整初始化（含 Git 子模块和 tmux 插件）：

```sh
bash ~/scripts/bootstrap.sh
```

首次安装可先下载 `bootstrap.sh`，再用 Bash 执行；脚本会在 `~/.mycfg` 不存在时 clone 并 checkout。
已有同名配置导致 checkout 冲突时，先自行备份、处理冲突；脚本不会强制覆盖。
bootstrap 会自动在 `${ZDOTDIR:-$HOME}/.zshrc` 中加入 `source "$HOME/scripts/init_zsh.sh"`；
已有加载行时不会重复添加。安装完成后打开新的 Zsh 会话。

## 按平台维护

| 平台 | 安装脚本 | 包清单 |
| --- | --- | --- |
| Linux | `scripts/linux/install.sh` | `scripts/linux/aqua.yaml` |
| macOS | `scripts/macos/install.sh` | `scripts/macos/Brewfile` |

统一入口通过 `uname -s` 分发，不支持的系统会报错退出。
默认安装 Node.js、fd、fzf、ripgrep、Neovim、tree-sitter CLI 和 tmux；macOS 还安装 zsh。
Node.js 保留，用于 Mason 安装的 npm 工具；Python 不默认安装，uv 按需选择。
已移除 pynvim、mise 和旧的远程插件注册步骤。

Linux 需预先准备 Git、curl、Bash、tar、sha256sum、C/C++ 编译器、make 和 zsh；
这些系统依赖使用发行版的包管理器安装。tmux 通过 aqua 的 `tmux/tmux-builds` 安装上游预编译包，
支持 Linux x86_64 和 ARM64，无需单独编译。
aqua 缺失时会安装，默认版本在 `linux/install.sh` 中固定，可用 `AQUA_VERSION` 覆盖首次安装版本。
aqua 使用固定版本包清单，环境在 `env.sh` 中配置；全局配置保证离开 `$HOME` 后工具仍可用。
已有 `AQUA_ROOT_DIR`、`XDG_DATA_HOME`、`XDG_CONFIG_HOME` 和其他 `AQUA_GLOBAL_CONFIG` 条目会保留。
Linux 的 npm 全局安装目录默认是 `${XDG_DATA_HOME:-$HOME/.local/share}/npm-global`，可用 `NPM_CONFIG_PREFIX` 覆盖。

### Linux glibc 兼容配置

Linux 最低要求 glibc 2.28。bootstrap 在 clone、checkout 和子模块初始化前检查版本；
单独安装软件或生成配置也会检查，低于 2.28 时直接报错退出。
安装时用 `getconf GNU_LIBC_VERSION` 检测 glibc，从 `scripts/linux/aqua.yaml`
生成 `${XDG_CONFIG_HOME:-$HOME/.config}/mycfg/aqua.yaml`。
生成文件由安装脚本和 shell 的 `AQUA_GLOBAL_CONFIG` 共用，不提交到 Git；
版本仍只在源清单中维护，不因机器不同而降级。支持 Linux x86_64 和 ARM64；
无法检测 glibc、glibc < 2.28 或不支持的架构会直接报错，保留上次生成的配置。

| 软件（当前固定版本） | glibc 条件 | 安装来源 |
| --- | --- | --- |
| Neovim 0.12.5 | 2.28 ≤ glibc < 2.34 | [neovim/neovim-releases](https://github.com/neovim/neovim-releases)（glibc 2.17 构建） |
| tree-sitter CLI 0.27.0 | 2.28 ≤ glibc < 2.39 | [arusuki/tree-sitter-releases](https://github.com/arusuki/tree-sitter-releases)（glibc 2.17 构建） |
| 以上软件 | 满足各自门槛 | aqua standard registry 的上游构建 |

兼容包定义在 `linux/registry.yaml` 的 `mycfg-compat` 本地 registry 中，保留原包名，
tree-sitter 使用 release 的 `SHA256SUMS` 校验。`env.sh` 加载 `linux/aqua-policy.yaml`
以允许这两个兼容包，并保留其他 `AQUA_POLICY_CONFIG` 条目。
全局配置加载时会替换继承的源清单条目，避免新 shell 继续选中不兼容的上游包；
卸载菜单也识别兼容 registry。
更换系统或更新清单后重新运行安装入口即可重新选择；也可只生成配置：

```sh
bash ~/scripts/linux/generate-aqua.sh
source ~/scripts/env.sh
```

已检查当前 release 的 ELF 符号要求：x86_64 的 fd、fzf、ripgrep、tmux 以及可选 uv
不依赖系统 glibc，均已在 glibc 2.31 上验证启动。Node.js 24.21.0 的 x86_64 构建
需要 glibc >= 2.28，ARM64 的 ripgrep 15.2.0 需要 glibc >= 2.18，
均满足本配置的最低版本要求。此检查不涵盖 Mason/npm 后续下载的工具
及 uv 下载的 Python，也不代表对更旧内核或其他系统库的兼容保证。

### macOS

macOS 需先安装 Xcode Command Line Tools（`xcode-select --install`）。
Homebrew 缺失时执行官方安装器，之后通过 `brew bundle install` 安装或升级清单中的软件。
环境配置支持 PATH 中的 Homebrew，以及 Apple Silicon `/opt/homebrew` 和 Intel `/usr/local` 路径。
两端均由包管理器提供 Neovim、tree-sitter CLI 和 tmux。

## 验证安装

先运行 `bash ~/scripts/install_packages.sh`，再打开新的 Zsh 会话，检查：

```sh
command -v nvim tree-sitter tmux
nvim --version
tree-sitter --version
tmux -V
```

Linux 的命令应来自 aqua 的 `bin` 目录，macOS 则来自 Homebrew。

## 可选 uv

`bootstrap.sh` 在交互终端中询问是否安装 uv，回车默认跳过。
非交互运行默认跳过；也可显式指定，无需回答提示：

```sh
bash ~/scripts/bootstrap.sh --with-uv
bash ~/scripts/bootstrap.sh --without-uv

# Packages only, including uv.
bash ~/scripts/install_packages.sh --with-uv
```

Linux 使用独立的 `linux/uv.yaml` 清单，安装后才在 shell 中启用对应全局配置；
macOS 的 Brewfile 根据本次选择包含 uv。
选择只影响本次安装，不修改包清单；跳过 uv 不会卸载已经安装的 uv。
Linux 更新 uv 版本可使用 `aqua -c ~/scripts/linux/uv.yaml update -p`。
需要 Python 时可另外运行 `uv python install`；不影响默认配置初始化。

## 卸载

```sh
bash ~/scripts/uninstall.sh           # Interactive selection.
bash ~/scripts/uninstall.sh --dry-run
bash ~/scripts/uninstall.sh --keep-uv
```

菜单中 `[x]` 表示**卸载**，`[ ]` 表示**保留**。
使用方向键或 `j` / `k` 移动，空格切换勾选，Enter 查看执行清单，`q` 取消。
清单确认后输入 `y` 才实际执行；预览模式直接输出命令。
列表会随光标滚动，无需安装额外的菜单工具。

- aqua 和 Homebrew 各自显示为根节点，可以同时出现。
- 勾选包管理器根节点，会强制勾选并锁定其所有子项，同时卸载管理器本身。
  取消根节点勾选后，恢复之前各软件的单独选择。
- aqua 通过 `aqua list -a -installed` 列出当前及全局配置中的已安装软件，
  同一个包的多个版本合并显示；单项卸载会删除该包的所有已安装版本及命令链接。
- Homebrew 显示全部已安装的 formula 和 cask，包括 bootstrap 清单以外的软件。
- 默认保留包管理器，勾选当前平台 bootstrap 清单中已安装的软件、tmux 插件和已初始化子模块；
  清单之外的软件默认不勾选。`--keep-uv` 只改变默认选择，勾选其根节点时 uv 仍会被强制勾选。
- tmux 插件和 Git 子模块也可逐项保留，或通过各自的“全选”根节点一起勾选。

勾选 aqua 根节点会删除整个 aqua 数据目录（包括未列出的旧版本、缓存和内置管理器），
遵循 `AQUA_ROOT_DIR` / `XDG_DATA_HOME`；对过于宽泛的路径或非 aqua 安装器管理的目录会拒绝删除。
由 Homebrew 等其他方式安装的 aqua 可通过对应包管理器卸载。
勾选 Homebrew 根节点会先卸载全部 cask，再下载并运行 Homebrew 官方卸载器；
这会删除整个 Homebrew 安装，可能需要系统权限。保留 Homebrew 时，仅卸载勾选的软件，
仍执行其依赖检查，不自动清理其他未选中的依赖。卸载失败会报错，并返回非零状态。

非交互执行必须显式指定 `--yes`，它使用上述默认选择并保留包管理器：

```sh
bash ~/scripts/uninstall.sh --yes --keep-uv
bash ~/scripts/uninstall.sh --dry-run  # Uses defaults without a terminal.
```

实际执行卸载时，会自动删除 `${ZDOTDIR:-$HOME}/.zshrc` 中本配置的独立加载行。
兼容 `source` / `.`、`$HOME` / `${HOME}` / `~` / HOME 绝对路径及常见引号写法，
保留其他配置、文件权限和符号链接；取消或预览时不修改文件。
bootstrap 和 uninstall 应使用相同的 `ZDOTDIR`。重新运行 bootstrap 可恢复加载行和安装。

安装脚本未记录软件是否在 bootstrap 之前就已存在，同名既有软件也会列入默认选择。
配置文件、`~/.mycfg`、系统依赖、旧 mise、npm 全局包、uv 管理的 Python/虚拟环境及
Neovim 数据均保留（自定义数据目录若放在所删除的包管理器目录内，则随该目录一起删除）。
子模块有本地修改时 Git 会拒绝取消初始化；tmux 插件有修改或未跟踪文件时保留并报错。
子模块的 Git 数据保留在 `~/.mycfg/modules`。
tmux 插件目录默认是 `~/.tmux/plugins`，自定义目录需通过 `TMUX_PLUGIN_MANAGER_PATH` 传入；
通过其他文件或运行中的 tmux 会话额外声明的插件需自行处理。
当前 shell 和 tmux 会话不会被终止；保留的 `.tmux.conf` 中 TPM 加载行在卸载 TPM 后需要自行禁用。

命令参考：[aqua 已安装软件列表](https://aquaproj.github.io/docs/guides/list-installed-packages/)、
[aqua 软件卸载](https://aquaproj.github.io/docs/guides/uninstall-packages/)、
[aqua 卸载](https://aquaproj.github.io/docs/reference/uninstall/)、
[Homebrew 软件卸载](https://docs.brew.sh/Manpage#uninstall-remove-rm-options-installed_formulainstalled_cask-)及
[Homebrew 官方卸载器](https://github.com/Homebrew/install/blob/HEAD/uninstall.sh)。

## 更新及提交

Linux 新增包可使用 `aqua -c ~/scripts/linux/aqua.yaml generate -i OWNER/REPO`。
更新包版本使用 `aqua -c ~/scripts/linux/aqua.yaml update -p`，仅更新 registry 则将 `-p` 换成 `-r`；
检查清单差异后重新运行安装入口。macOS 直接编辑 Brewfile。
不要直接更新生成的 `~/.config/mycfg/aqua.yaml`。更新 Neovim 或 tree-sitter 版本时，
确认兼容仓库有相同 tag，并重新核对 `linux/generate-aqua.sh` 中的 glibc 门槛。
离线回归检查：`bash ~/scripts/tests/aqua.sh`（覆盖版本边界、Bash/Zsh 环境和安装入口）。

```sh
config diff -- .gitmodules scripts .config/nvim/init.lua
config add .gitmodules scripts .config/nvim/init.lua
config diff --cached
```

`config` 默认隐藏未跟踪文件，新增脚本需显式 `config add`。
现有 mise 安装及其下载的工具不会被卸载，但新 shell 配置不再添加 mise shims。

参考：[aqua 全局配置](https://aquaproj.github.io/docs/tutorial/global-config/)、
[aqua Node.js 配置](https://aquaproj.github.io/docs/reference/nodejs-support/)、
[Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile)。
