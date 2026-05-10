# nix-config

[English](./README.md) | **简体中文**

个人 NixOS 配置仓库。框架结构参考自
[ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)。

## 目录结构

```
flake.nix                     flake 入口;outputs = import ./outputs
outputs/                      按架构聚合(haumea 自动加载 src/ 下的主机文件)
lib/                          工厂函数(nixosSystem / scanPaths / ...)
vars/                         全局变量(用户名、SSH key、密码哈希等)
hosts/<name>/                 主机特有:硬件、disko、预存储等
modules/base/                 跨平台共享系统模块
modules/nixos/base/           NixOS 强制基础(自动导入)
modules/nixos/desktop/        NixOS 桌面组(opt-in:modules.desktop.<de>.enable)
modules/nixos/server/         NixOS 服务器模块(按主机显式导入)
home/base/home.nix            home-manager 状态(stateVersion、用户名)
home/base/core/               日常基线:git、ssh、starship、direnv、eza、bat、tmux、btop、yazi、CLI 小工具
home/base/tui/                工作站 dev 增强(预留 —— 未来加 pgcli / k9s / tokei / ...)
home/base/gui/                跨平台 GUI:kitty、media(ffmpeg / imagemagick 等)、dev-tools(AI agents)
home/linux/core.nix           Linux 入口:纯 CLI
home/linux/tui.nix            Linux 入口:core + TUI 工具
home/linux/gui.nix            Linux 入口:core + TUI + GUI
home/linux/gui/base/          Linux GUI,DE 无关:GTK 主题、Firefox(沙箱)、Chrome、fcitx5 中文输入法、gaming(opt-in)
home/linux/gui/plasma.nix     Plasma / KDE 用户应用
home/hosts/<name>.nix         一台主机一个 home 模块(选一个入口)
hardening/                    opt-in 沙箱:nixpaks/、bwraps/、profiles/
```

## 主机列表

| 主机 | 角色 | Home 入口 | 桌面 |
|------|------|-----------|------|
| `faex1` | 物理桌面机 | `linux/gui.nix` | KDE Plasma 6 |
| `pve-lab1` | Proxmox VE 实验 VM | `linux/gui.nix` | KDE Plasma 6 |

## 桌面环境

KDE Plasma 6 按 options 开关模式接入,**系统级 / 用户级** 清晰分离:

| 层级 | 位置 | 内容 |
|------|------|------|
| 系统级 | `modules/nixos/desktop/plasma.nix` | SDDM、Plasma service、pipewire、显卡驱动、打印、系统字体 |
| 用户级 | `home/linux/gui/plasma.nix` | KDE 应用(kate / ark / gwenview / okular / spectacle …) |
| 用户级 | `home/linux/gui/gtk.nix` | GTK 鼠标/字体主题,让 GTK 应用在 Plasma 里视觉统一 |

主机通过 `modules.desktop.plasma.enable = true;` 启用系统层,home 侧选 `gui.nix` 入口自动带入用户层。

**加新桌面(Hyprland / GNOME / ...)**:在上面两个位置各新加一个 `<de>.nix`,
主机里用 `modules.desktop.<de>.enable = true;` 启用即可,不用动现有代码。

> nixpkgs 每个 channel 只对应一个 Plasma 版本。`nix flake update nixpkgs`
> 拉最新(当前 `nixos-unstable` 上是 Plasma 6.6)。

## Home 三层入口

```
core.nix    日常基线(任何主机):git、shell、tmux、btop、direnv 等
tui.nix     core + base/tui:工作站 dev 增强(预留 —— 当前为空)
gui.nix     tui + linux/gui:KDE 应用、GTK 主题
```

叠加关系:**core ⊂ tui ⊂ gui**。每台主机的 `home/hosts/<name>.nix`
显式选**一个**入口 —— `home/linux/` 下没有 `default.nix`,避免误导入。

## 沙箱机制

三层 opt-in 安全沙箱,详见 [hardening/README.md](./hardening/README.md):

| 层 | 位置 | 作用 |
|----|------|------|
| **系统加固** | `hardening/profiles/` | NixOS 官方 hardened profile(激进,可能影响游戏/虚拟化) |
| **Nixpak 单应用沙箱** | `hardening/nixpaks/` | 声明式 bubblewrap,暴露到 `pkgs.nixpaks.<app>` |
| **Bwrap 单应用沙箱** | `hardening/bwraps/` | 原生 bubblewrap,适合 AppImage,暴露到 `pkgs.bwraps.<app>` |

示例主机默认导入了 nixpaks + bwraps 两个 overlay(**不占资源**,
不引用任何应用时完全是空跑);`profiles/` 需要手动打开。

新增被沙箱化的应用:
1. 在 `hardening/nixpaks/` 或 `hardening/bwraps/` 下新增 `<app>.nix`
2. 在对应 `default.nix` overlay 里注册一行
3. 在模块里用 `pkgs.nixpaks.<app>` 或 `pkgs.bwraps.<app>` 引用

可参考 `ryan4yin-nix-config/hardening/nixpaks/firefox.nix` / `bwraps/wechat.nix`。

## 首次部署

1. **在目标机器上**生成硬件配置:
   ```bash
   sudo nixos-generate-config --dir ./hw-dump
   ```
   把 `hw-dump/hardware-configuration.nix` 复制进 `hosts/<主机>/`,替换占位文件。

2. 填写 `vars/default.nix` —— 设置 `username`、`useremail`、SSH 公钥,
   以及 `initialHashedPassword`(用 `mkpasswd -m yescrypt --rounds=11` 生成)。

3. (可选)重命名主机:三个位置同步改 ——
   - `outputs/x86_64-linux/src/<name>.nix` (并改文件里的 `name`)
   - `hosts/<name>/`
   - `home/hosts/<name>.nix`

4. 部署:
   ```bash
   just switch <主机>
   # 或
   sudo nixos-rebuild switch --flake .#<主机>
   ```

## 新增主机

1. 在 `outputs/x86_64-linux/src/<host>.nix` 新建主机声明文件
2. 建 `hosts/<host>/`(含 `default.nix` 和 `hardware-configuration.nix`)
3. 建 `home/hosts/<host>.nix`,从 `core / tui / gui` 三个入口**选一个**
4. 如果是 PVE / KVM 虚拟机,模块列表里加 `modules/nixos/server/qemu-guest.nix`

haumea 会自动识别,无需手动 import。

## 常用命令

```bash
just              # 列出所有命令
just switch <主机> # 构建并切换到主机 <主机>
just build <主机>  # 只构建不切换
just update       # 更新所有 flake inputs
just fmt          # 格式化全部 nix 文件
just check        # 跑 eval-tests + pre-commit 检查
```

## 架构核心机制(改代码前先懂这四个)

| 机制 | 位置 | 作用 |
|------|------|------|
| **haumea 自动加载** | `outputs/<sys>/default.nix` | `src/` 下扔文件即生效,零样板 |
| **工厂函数** | `lib/nixosSystem.nix` | 主机文件只拼 modules 列表,不写 nixosSystem 细节 |
| **specialArgs 注入** | `outputs/default.nix` | 全局注入 `mylib / myvars / pkgs-stable`,避免到处硬编码 |
| **options 开关式模块** | `modules/` | 用 `modules.xxx.enable = true;` 启用功能,不用无条件 `imports` |

破坏这四个机制 = 结构会越写越乱。详见 [CLAUDE.md](./CLAUDE.md)。
