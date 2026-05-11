# home/base

[English](./README.md) | **简体中文**

跨平台 home-manager 配置。这里的东西必须在 Linux 和 macOS 上**都能跑**,
以便被 `home/linux/` 和(未来的)`home/darwin/` 入口复用。

## 结构

```
home/base/
├── home.nix     home-manager 状态(stateVersion、username)—— 所有入口都会导入
├── core/        日常基线(任何主机):git、starship、direnv、eza、bat、tmux、btop、yazi、cli-tools
├── tui/         工作站 dev 增强(预留 —— 未来加 pgcli / k9s / tokei / ...)
└── gui/         跨平台 GUI:kitty、media(ffmpeg / viu / imagemagick)、dev-tools(网络调试)、ai-agents(opt-in)
```

每个子目录都有 `default.nix` 用 `scanPaths` 自动扫描同级文件 —— 往对应
目录扔一个 `<name>.nix` 就自动生效,不用再改入口文件。

## 怎么决定文件放哪

| 目录 | 判断原则 |
|------|---------|
| `core/` | **日常基线 —— 任何主机都要。** git、shell、进程监控、会话多路复用、文件工具。无 GUI 也能跑。 |
| `tui/` | **工作站 dev 增强。** 只在开发时有用的工具 —— git TUI、DB 客户端、k8s 工具、语言服务器。纯跑服务的主机可以跳过。 |
| `gui/` | **同时**能在 Linux 和 macOS 上跑的图形应用。Linux 专属 GUI(GTK 主题、fcitx5、niri 配置)应该放 `home/linux/gui/` |

## 这些内容从哪里被引入

```
home/linux/core.nix   导入 base/home.nix + base/core
home/linux/tui.nix    在 core 之上叠加 base/tui
home/linux/gui.nix    在 tui 之上叠加 base/gui + linux/gui
```

主机在 `home/hosts/<name>.nix` 里**选一个**入口。
`home/linux/` 下**没有** `default.nix` —— 必须显式指定。

## `programs.<tool>` vs `home.packages`

home-manager 提供**两种**"装工具"的方式,选错会**静默丢失**一堆能力。

| 情况 | 用哪个 | 举例 |
|------|--------|------|
| home-manager 有 `programs.<tool>` 模块 | **`programs.<tool>`,独立文件 `<tool>.nix`** | `eza.nix`、`bat.nix`、`btop.nix`、`starship.nix`、`git.nix` |
| home-manager 没这个模块(纯二进制) | `home.packages`,合在 `cli-tools.nix` 里 | `ripgrep`、`fd`、`jq` |

`programs.<tool>.enable = true;` **不止是装** —— 它还会:
- 生成工具的配置文件(`~/.config/<tool>/...`)
- 自动加 shell 别名 / 集成(如 `ls → eza`、direnv hook)
- 套一套稳妥的默认值

用 `home.packages = [ pkgs.<tool> ]` **只能拿到二进制本身**,上面这些能力全部静默丢失。

**查可用性**:`nix repl` → `:lf <home-manager>` → `options.programs.<tool>`,
或上 [home-manager-options.extranix.com](https://home-manager-options.extranix.com/)。

**有 `programs.<tool>` 模块就用它 —— 就算暂时没配置。** 一行
`programs.<tool>.enable = true;`(空配置)也比 `home.packages` 强,
因为你保留了"以后想加集成 / 默认值时能直接加"的位置。

## 新增跨平台应用

1. 选桶:纯 CLI → `core/`,交互式终端 → `tui/`,图形应用 → `gui/`
2. 查 home-manager 是否有 `programs.<app>`(参考上表)
3. 在对应目录扔 `<app>.nix`,按上表选 `programs.<app>` 或 `home.packages`
4. 完成 —— 没有什么清单要更新,`scanPaths` 会自动识别

如果应用是 **Linux 专属**(比如 Wayland 专用工具),放到 `home/linux/` 下而不是这里。
