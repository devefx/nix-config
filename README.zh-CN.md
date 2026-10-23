# nix-config

[English](./README.md) | **简体中文**

个人 NixOS 配置仓库。框架结构参考自 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)。

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
home/base/tui/                工作站 dev 增强(Rust 工具链 opt-in;未来加 pgcli / k9s / tokei / ...)
home/base/gui/                跨平台 GUI:kitty、media(ffmpeg / imagemagick 等)、dev-tools(网络调试)、ai-agents(opt-in)
home/linux/core.nix           Linux 入口:纯 CLI
home/linux/tui.nix            Linux 入口:core + TUI 工具
home/linux/gui.nix            Linux 入口:core + TUI + GUI
home/linux/gui/base/          Linux GUI,DE 无关:GTK 主题、Firefox(沙箱)、Chrome、fcitx5 中文输入法、gaming(opt-in)
home/linux/gui/plasma.nix     Plasma / KDE 用户应用
home/linux/gui/niri/          Niri 快捷键、窗口规则、Noctalia Shell
home/hosts/<name>.nix         一台主机一个 home 模块(选一个入口)
hardening/                    opt-in 沙箱:nixpaks/、bwraps/、profiles/
```

## 主机列表

| 主机         | 角色       | Home 入口       | 桌面            |
| ------------ | ---------- | --------------- | --------------- |
| `faex1`      | 物理桌面机 | `linux/gui.nix` | KDE Plasma 6    |
| `faex1-niri` | 同一台机器 | `linux/gui.nix` | Niri + Noctalia |

## 桌面环境

KDE Plasma 6 按 options 开关模式接入,**系统级 / 用户级** 清晰分离:

| 层级   | 位置                               | 内容                                                                     |
| ------ | ---------------------------------- | ------------------------------------------------------------------------ |
| 系统级 | `modules/nixos/desktop/plasma.nix` | Plasma Login Manager、Plasma service、pipewire、显卡驱动、打印、系统字体 |
| 用户级 | `home/linux/gui/plasma.nix`        | 桌面应用(kate / ark / qimgv / okular / spectacle …)                      |
| 用户级 | `home/linux/gui/base/gtk.nix`      | GTK 鼠标/字体主题,让 GTK 应用在 Plasma 里视觉统一                        |

主机通过 `modules.desktop.plasma.enable = true;` 启用系统层,home 侧选 `gui.nix` 入口自动带入用户层。

Niri 也走同一套 options 分层,并额外提供 `faex1-niri` 输出:

| 层级   | 位置                             | 内容                                                    |
| ------ | -------------------------------- | ------------------------------------------------------- |
| 系统级 | `modules/nixos/desktop/niri.nix` | Niri、greetd、PipeWire、portals、XWayland satellite     |
| 用户级 | `home/linux/gui/niri/`           | KDL 快捷键 / 窗口规则、Noctalia Shell、截图和剪贴板工具 |

切换会话:

```bash
sudo nixos-rebuild switch --flake .#faex1-niri
# 回到 Plasma
sudo nixos-rebuild switch --flake .#faex1
```

**加新桌面(Hyprland / GNOME / ...)**:在上面两个位置各新加一个 `<de>.nix`, 主机里用
`modules.desktop.<de>.enable = true;` 启用即可,不用动现有代码。

> nixpkgs 每个 channel 只对应一个 Plasma 版本。`nix flake update nixpkgs` 拉最新(当前
> `nixos-unstable` 上是 Plasma 6.6)。

## Niri 快捷键

`Mod` 在 TTY 会话中对应 Super。Noctalia Shell 默认使用简体中文(`zh-CN`)。按 `Mod+Shift+/`
可以打开 niri 内置快捷键提示;完整配置见
[`keybindings.kdl`](./home/linux/gui/niri/conf/keybindings.kdl)。

### 启动与会话

| 操作               | 快捷键                           |
| ------------------ | -------------------------------- |
| 打开终端           | `Mod+Return`、`Mod+Shift+Return` |
| 打开应用启动器     | `Mod+D`、`Mod+Space`、`Search`   |
| 锁屏               | `Ctrl+Alt+L`                     |
| 打开会话菜单       | `Mod+E`                          |
| 显示快捷键提示     | `Mod+Shift+/`                    |
| 关闭当前窗口       | `Mod+Q`                          |
| 退出 niri          | `Ctrl+Alt+Delete`                |
| 关闭显示器         | `Mod+Shift+P`                    |
| 切换快捷键拦截状态 | `Mod+Escape`                     |

### 导航

| 操作                       | 快捷键                             |
| -------------------------- | ---------------------------------- |
| 焦点移到左/右列            | `Mod+Left/H`、`Mod+Right/L`        |
| 焦点移到列内上/下窗口      | `Mod+Up/K`、`Mod+Down/J`           |
| 焦点移到第一列/最后一列    | `Mod+Home`、`Mod+End`              |
| 焦点移到左/右/上/下显示器  | `Mod+Shift+方向键/HJKL`            |
| 焦点移到上/下工作区        | `Mod+Page_Up/I`、`Mod+Page_Down/U` |
| 焦点移到命名工作区 1-5 / 0 | `Mod+1` 至 `Mod+5`、`Mod+0`        |

命名工作区依次为 `1terminal`、`2browser`、`3chat`、`4entertainment`、`5utility` 和 `0other`。

### 移动与布局

| 操作                          | 快捷键                                         |
| ----------------------------- | ---------------------------------------------- |
| 左/右移动列                   | `Mod+Ctrl+Left/H`、`Mod+Ctrl+Right/L`          |
| 在列内上/下移动窗口           | `Mod+Ctrl+Up/K`、`Mod+Ctrl+Down/J`             |
| 将列移到最前/最后             | `Mod+Ctrl+Home`、`Mod+Ctrl+End`                |
| 将列移到其他显示器            | `Mod+Shift+Ctrl+方向键/HJKL`                   |
| 将列移到上/下工作区           | `Mod+Ctrl+Page_Up/I`、`Mod+Ctrl+Page_Down/U`   |
| 将列移到命名工作区 1-5 / 0    | `Mod+Ctrl+1` 至 `Mod+Ctrl+5`、`Mod+Ctrl+0`     |
| 上/下移动工作区               | `Mod+Shift+Page_Up/I`、`Mod+Shift+Page_Down/U` |
| 向左/右合并或拆出窗口         | `Mod+[`、`Mod+]`                               |
| 将窗口合并到当前列/从列中拆出 | `Mod+,`、`Mod+.`                               |
| 循环预设列宽                  | `Mod+R`                                        |
| 循环预设窗口高度/重置高度     | `Mod+Shift+R`、`Mod+Ctrl+R`                    |
| 最大化列/窗口全屏             | `Mod+F`、`Mod+Shift+F`                         |
| 扩展列/居中可见列             | `Mod+Ctrl+F`、`Mod+Ctrl+C`                     |
| 调整列宽                      | `Mod+-`、`Mod+=`                               |
| 调整窗口高度                  | `Mod+Shift+-`、`Mod+Shift+=`                   |
| 切换浮动窗口                  | `Mod+V`                                        |
| 切换标签式列显示              | `Mod+W`                                        |

### 工具与硬件按键

| 操作                           | 快捷键                                        |
| ------------------------------ | --------------------------------------------- |
| 剪贴板历史                     | `Mod+Shift+V`                                 |
| 计算器                         | `Mod+C`                                       |
| 控制中心                       | `Mod+S`                                       |
| 使用 Satty 标注截图            | `Print`                                       |
| 截图识别文字                   | `Mod+Shift+O`                                 |
| 截取整屏/当前窗口              | `Ctrl+Print`、`Alt+Print`                     |
| 音量加/减/静音                 | `Volume Up`、`Volume Down`、`Volume Mute`     |
| 麦克风静音                     | `Microphone Mute`                             |
| 播放/暂停、停止、上一首/下一首 | `Media Play`、`Media Stop`、`Media Prev/Next` |
| 屏幕亮度加/减                  | `Brightness Up`、`Brightness Down`            |
| 键盘背光加/减                  | `Keyboard Brightness Up/Down`                 |

## Home 三层入口

```
core.nix    日常基线(任何主机):git、shell、tmux、btop、direnv 等
tui.nix     core + base/tui:工作站 dev 增强(Rust 工具链 opt-in)
gui.nix     tui + linux/gui:KDE 应用、GTK 主题
```

叠加关系:**core ⊂ tui ⊂ gui**。每台主机的 `home/hosts/<name>.nix` 显式选**一个**入口 ——
`home/linux/` 下没有 `default.nix`,避免误导入。

## 沙箱机制

三层 opt-in 安全沙箱,详见 [hardening/README.md](./hardening/README.md):

| 层                    | 位置                  | 作用                                                     |
| --------------------- | --------------------- | -------------------------------------------------------- |
| **系统加固**          | `hardening/profiles/` | NixOS 官方 hardened profile(激进,可能影响游戏/虚拟化)    |
| **Nixpak 单应用沙箱** | `hardening/nixpaks/`  | 声明式 bubblewrap,暴露到 `pkgs.nixpaks.<app>`            |
| **Bwrap 单应用沙箱**  | `hardening/bwraps/`   | 原生 bubblewrap,适合 AppImage,暴露到 `pkgs.bwraps.<app>` |

示例主机默认导入了 nixpaks +
bwraps 两个 overlay(**不占资源**, 不引用任何应用时完全是空跑);`profiles/` 需要手动打开。

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

2. 填写 `vars/default.nix` —— 设置 `username`、`useremail`、SSH 公钥, 以及
   `initialHashedPassword`(用 `mkpasswd -m yescrypt --rounds=11` 生成)。

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

## 本地推理(gufo)

[gufo](https://github.com/gufo-org/gufo) 是专为 Strix Halo(gfx1151)优化的推理引擎, 通过
`modules/nixos/server/gufo.nix` 暴露成
`modules.gufo.*`,由 systemd 托管成 OpenAI兼容服务。前置条件(本仓库已满足):用户在 `render` / `video`
组内,且 `ttm.pages_limit` 已调高(`hosts/faex1/default.nix` 设到 96 GiB)。

模型权重不进 store(Flash-Next Q4 约 104 GiB),模块本身不下载、也不创建这些文件。 `model` / `mmproj` /
`mtpModel` 都从 `modules.gufo.modelsDir` 派生,默认 `~/models`
——这样"权重到底放哪块盘"由你自己的符号链接决定,而不是写死在 Nix 字符串里:

```bash
ln -s /mnt/data/Shared/github/workspace/gguf-model-presets/models ~/models
```

期望的目录结构,以及下载命令(要拆成两条 `hf` 命令 —— 同时给显式文件名和 `--include` 时 `hf`
会静默忽略 glob):

```bash
D=~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL
R=38bb39ee97821de2c9009abb7e93950eec396e66
hf download unsloth/Qwen3.8-Flash-Next-GGUF --revision "$R" \
  --include "UD-Q4_K_XL/*" --local-dir "$D"
hf download unsloth/Qwen3.8-Flash-Next-GGUF --revision "$R" --local-dir "$D" \
  MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf mmproj-BF16.gguf
```

```
~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL/
├── UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-0000{1..4}-of-00004.gguf
├── MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
└── mmproj-BF16.gguf
```

然后在主机里开:

```nix
modules.gufo = {
  enable = true;
  port = 8080;
  # modelsDir = "/srv/llm/models";  # ~/models 不合适时覆盖
  context = 262144;  # 原生上下文;96 GiB GTT 机器实测占 90.1 GiB
  sessions = 1;      # 每个额外 session 约 1.06 GiB;2x131072 放不下
};
```

本机 96 GiB GTT 实测显存占用:1x32768 = 84.25 GiB,2x32768 = 85.31 GiB, 1x131072 = 86.76 GiB,1x262144
= 90.12 GiB。其中约 82.4 GiB 是权重加固定开销,每个 session 1.06 GiB,每 1K token 的 KV 约 26.8 MiB
—— 所以单 session 就能装下原生 256K 上下文, 不需要调 `ttm.pages_limit`。

`systemctl status gufo` 看状态,`curl localhost:8080/v1/models` 验证。

## 常用命令

```bash
just              # 列出所有命令
just switch <主机> # 构建并切换到主机 <主机>
just build <主机>  # 只构建不切换
just update       # 更新所有 flake inputs
just fmt          # 格式化全部 nix 文件
just check        # 跑 pre-commit 检查 + 求值所有主机
```

## 架构核心机制(改代码前先懂这四个)

| 机制                   | 位置                        | 作用                                                          |
| ---------------------- | --------------------------- | ------------------------------------------------------------- |
| **haumea 自动加载**    | `outputs/<sys>/default.nix` | `src/` 下扔文件即生效,零样板                                  |
| **工厂函数**           | `lib/nixosSystem.nix`       | 主机文件只拼 modules 列表,不写 nixosSystem 细节               |
| **specialArgs 注入**   | `outputs/default.nix`       | 全局注入 `mylib / myvars / pkgs-stable`,避免到处硬编码        |
| **options 开关式模块** | `modules/`                  | 用 `modules.xxx.enable = true;` 启用功能,不用无条件 `imports` |

破坏这四个机制 = 结构会越写越乱。详见 [CLAUDE.md](./CLAUDE.md)。
