# home/

Home Manager 用户环境配置，采用与 `modules/` 相同的三层拆分：

```
home/
├── base/      # 跨平台共享（所有主机都会加载）
├── linux/     # Linux 专用配置
└── darwin/    # macOS 专用配置
```

## 三层拆分说明

| 层级 | 加载时机 | 典型内容 |
|---|---|---|
| `base/` | 所有主机 | Shell (zsh + starship)、Git、编辑器、通用 CLI 工具 |
| `linux/` | 仅 Linux 主机 | homeDirectory 设置、systemd 服务重载、Linux GUI 应用 |
| `darwin/` | 仅 macOS 主机 | homeDirectory 设置、macOS 专属应用和配置 |

## 当前文件

### base/
| 文件 | 内容 |
|---|---|
| `default.nix` | 入口：设置 username、通用包 (ripgrep, fd, jq, bat, eza, fzf) |
| `shell.nix` | Zsh + autosuggestion + syntax-highlighting + starship + direnv + fzf |
| `git.nix` | Git 配置 + delta (美化 diff) |
| `editor.nix` | Neovim 作为默认编辑器 |

### linux/
- `default.nix` — 设置 `homeDirectory = "/home/username"`、systemd 用户服务自动重载

### darwin/
- `default.nix` — 设置 `homeDirectory = "/Users/username"`

## 集成方式

Home Manager 以 **NixOS/Darwin module** 模式集成（非独立模式），由 `lib/nixosSystem.nix` 和 `lib/darwinSystem.nix` 自动处理。无需手动运行 `home-manager switch`，系统 rebuild 时自动应用。

## 扩展建议

```
home/base/
├── default.nix
├── shell.nix
├── git.nix
├── editor.nix
├── tmux.nix           # 终端复用
├── ssh.nix            # SSH 客户端配置
└── gpg.nix            # GPG 签名

home/linux/
├── default.nix
├── gui.nix            # GUI 应用 (Firefox, VS Code)
├── wayland.nix        # Wayland 合成器配置
└── gtk.nix            # GTK 主题

home/darwin/
├── default.nix
├── aerospace.nix      # Aerospace 窗口管理器
└── terminal.nix       # 终端模拟器偏好
```
