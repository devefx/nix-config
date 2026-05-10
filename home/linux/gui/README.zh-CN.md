# home/linux/gui

[English](./README.md) | **简体中文**

Linux 专属的 GUI 用户配置。通过 `home/linux/gui.nix` 的 `scanPaths`
被拉进来。

## 目录结构

```
home/linux/gui/
├── default.nix         scanPaths —— 自动扫描同级文件
├── base/               DE 无关(任何合成器/桌面都适用)
│   ├── default.nix     scanPaths
│   ├── gtk.nix         GTK 鼠标 + 字体(GTK 应用在任何 DE 下都生效)
│   ├── firefox.nix     Firefox(沙箱 —— 见 hardening/nixpaks/firefox.nix)
│   ├── chrome.nix      Google Chrome(unfree,有内置沙箱)
│   ├── fcitx5.nix      中文输入法(拼音 / 双拼 / 五笔)
│   └── lutris.nix      Linux 游戏启动器(Wine / Proton / GOG 等)
└── plasma.nix          Plasma / KDE 用户应用(kate、ark、gwenview ...)
```

## DE 无关(`base/`) vs DE 专属(同级其他文件)

| 放哪里 | 为什么 |
|--------|-------|
| `base/gtk.nix` | GTK 主题对 Firefox / VS Code 等 GTK 应用生效,和用哪个 DE / 合成器无关 |
| `plasma.nix` | Plasma / KDE 应用只在 Plasma 启用时有意义 |
| 以后加 `hyprland/` 子目录 | Hyprland 的快捷键、布局 —— 只在 Hyprland 是当前会话时才有意义 |
| 以后加 `base/fcitx5.nix` | 输入法在所有 DE 下都用 |

规则:**如果不依赖具体 DE/WM,就放 `base/` 下。**
只在特定合成器下才有意义的,放到那个合成器的子目录(或平铺的 `<de>.nix`)。

## 什么可以放在这个目录树下

Linux 专属的用户级 GUI 配置,跨平台的 `home/base/gui/` 装不下的:

- 桌面环境的应用(KDE、GNOME、Hyprland 的配套工具)
- 显示服务器相关的配置(Wayland 合成器快捷键、X11 xresources)
- Linux 输入法(fcitx5、ibus)
- GTK 主题(GTK 主要是 Linux 上的)

## 什么不应该放这里

| 应该去哪里 | 举例 |
|-----------|------|
| `home/base/gui/` | VS Code、Obsidian —— 在 Linux 和 macOS 上 home-manager 都支持好的应用 |
| `modules/nixos/desktop/` | KDE 的系统服务、SDDM、pipewire —— 需要 root 的东西 |

## 新增桌面环境的用户侧

1. 如果配置**和 DE 无关**(主题、输入法、通用辅助工具)
   → 扔到 `base/<name>.nix`
2. 如果配置**只对某一个 DE/合成器有意义** → 平铺 `<de>.nix` 放在
   `plasma.nix` 旁边,或者配置多时建 `<de>/` 子目录
3. 对应的系统模块放到 `modules/nixos/desktop/<de>.nix`
