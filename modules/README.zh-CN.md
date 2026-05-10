# modules

[English](./README.md) | **简体中文**

系统级模块(NixOS / nix-darwin)。所有要进 `/etc`、改 `/nix/store` 级
配置、挂 systemd 服务、动内核 / 启动项、装全系统软件包的内容都放这里。

用户级内容(按用户装的 app、dotfiles、主题)属于 `home/`,**不是这里**。

## 目录布局

```
modules/
├── base/          跨平台:nix 配置、用户 ...
└── nixos/
    ├── base/      NixOS 强制基础(自动导入)
    ├── desktop/   桌面组 —— opt-in,通过 modules.desktop.<de>.enable
    └── server/    服务器模块 —— server 主机显式导入
```

等以后加 macOS 主机,会多出一个同级的 `modules/darwin/`。

## 两种导入模式

子目录是"人人需要"还是"按需启用",接入方式不同。

| 模式 | 位置 | 加载方式 |
|------|------|---------|
| **自动导入** | `modules/base/`、`modules/nixos/base/` | 任何 import 了 `modules/nixos` 的主机自动带上(经由 `modules/nixos/default.nix`) |
| **显式导入** | `modules/nixos/server/<file>.nix` | 主机把具体文件加到自己的 `nixos-modules` 列表里 |
| **options 开关** | `modules/nixos/desktop/` | 整组被 import,但每个具体功能藏在 `modules.desktop.<de>.enable` 后面 |

## options 开关模式(扩展模块的正确姿势)

新功能别写"无条件生效",应该定义 option 然后 gate 起来:

```nix
{ lib, config, ... }:
with lib;
let cfg = config.modules.<area>.<feature>;
in {
  options.modules.<area>.<feature>.enable = mkEnableOption "<feature>";
  config = mkIf cfg.enable {
    # 真正的配置写在这里
  };
}
```

主机按需启用:

```nix
# hosts/<host>/default.nix
modules.<area>.<feature>.enable = true;
```

**未用到的功能零开销**,也避免了"mass import"副作用。

## 新增模块

1. 选桶:
   - 跨平台(macOS 上也适用)→ `modules/base/`
   - NixOS 专属基础(人人需要)→ `modules/nixos/base/`
   - 桌面环境 / 跟 GUI 相关的系统服务 → `modules/nixos/desktop/`
   - 服务器专用(虚拟化 guest、k8s 节点 ...)→ `modules/nixos/server/`
2. **非基础模块一律用上面的 options 模式**,别写无条件生效的。
3. 主机通过 `modules.<area>.<feature>.enable = true;` 启用。
