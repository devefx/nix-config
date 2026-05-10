# home/linux

[English](./README.md) | **简体中文**

Linux 专属的 home-manager 配置,以及主机 import 的入口文件都在这里。

## 目录内容

```
home/linux/
├── core.nix    入口:base/home.nix + base/core
├── tui.nix     入口:core + base/tui
├── gui.nix     入口:tui + base/gui + linux/gui
└── gui/        Linux 专属 GUI 用户配置
    ├── default.nix   scanPaths —— 自动扫描同级文件
    ├── base/         DE 无关(任何合成器/桌面都适用)
    │   ├── gtk.nix       GTK 鼠标/字体(让 GTK 应用视觉统一)
    │   ├── firefox.nix   Firefox(经 nixpak 沙箱 —— hardening/nixpaks/firefox.nix)
    │   ├── chrome.nix    Google Chrome(unfree,有自己内置沙箱)
    │   ├── fcitx5.nix    中文输入法(拼音 / 双拼 / 五笔)
    │   └── lutris.nix    Linux 游戏启动器(Wine / Proton / GOG 等)
    └── plasma.nix   Plasma / KDE 用户应用:kate、ark、gwenview 等
```

**此层没有 `default.nix`。** 主机必须从三个 `.nix` 入口里**显式**选一个。

## 为什么要三个入口

不同主机要的层级不一样:

- 只跑服务的服务器(nginx / postgres 盒子,不做开发)选 `core.nix` ——
  日常基线(git、tmux、btop、direnv),不带 dev 增强
- 开发活跃的无 GUI 的 VM / 工作站选 `tui.nix` ——
  预留给未来的 dev 工具(pgcli、k8s 客户端 ...),当前为空
- 桌面 / 有 GUI 的 VM(`faex1`、`pve-lab1`)选 `gui.nix` —— 含 KDE 应用 + GTK 主题

叠加关系:**core ⊂ tui ⊂ gui**。主机选 `gui.nix` 就自动带上
`tui.nix` 和 `core.nix` 里的所有东西。

## `linux/gui/` vs `base/gui/`

| 目录 | 内容 |
|------|------|
| `home/base/gui/` | 跨平台 GUI 应用 —— VS Code、Obsidian 这种在 Linux 和 macOS 上 home-manager 都支持好的 |
| `home/linux/gui/` | Linux 专属 GUI —— KDE 应用、GTK 主题、fcitx5、niri 快捷键等 |

加新 GUI 应用时先问:**macOS 上能跑吗?** 能 → 放 `home/base/gui/`;
不能 → 放 `home/linux/gui/`。

## 新增文件

扔一个 `.nix` 到合适的桶里,`default.nix` 里的 `scanPaths` 会自动
识别,无需改任何 manifest。
