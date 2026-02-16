# modules/

系统级 NixOS / Darwin 模块，采用三层拆分：

```
modules/
├── base/      # 跨平台共享（NixOS 和 macOS 都会加载）
├── nixos/     # NixOS 专用模块
└── darwin/    # macOS (nix-darwin) 专用模块
```

## 三层拆分说明

| 层级 | 加载时机 | 典型内容 |
|---|---|---|
| `base/` | 所有主机 | Nix 核心设置 (flakes, registry, gc)、overlays 注入、allowUnfree |
| `nixos/` | 仅 NixOS 主机 | 桌面环境、网络、字体、音频、i18n、SSH |
| `darwin/` | 仅 macOS 主机 | 系统偏好 (Dock, Finder, Trackpad)、Touch ID、Homebrew |

## 当前文件

### base/
- `nix.nix` — Nix 核心设置：启用 flakes、注册表同步、GC、overlays 注入

### nixos/
- `desktop.nix` — 桌面基础：NetworkManager、时区、PipeWire 音频、字体、常用包

### darwin/
- `system.nix` — macOS 偏好：Dock 自动隐藏、Finder 设置、键盘速度、Touch ID sudo

## 扩展建议

随着配置增长，按职责拆分文件：

```
modules/nixos/
├── default.nix
├── desktop.nix        # 桌面环境
├── networking.nix     # 网络 (proxy, VPN, tailscale)
├── virtualisation.nix # Docker, Podman, VMs
├── security.nix       # 防火墙, AppArmor
└── server.nix         # 服务器角色配置
```

## 与 home/ 的区别

- `modules/` = **系统级**配置 (需要 root 权限，影响整个系统)
- `home/` = **用户级**配置 (不需要 root，只影响当前用户的 dotfiles 和程序)
