# nix-config-template

个人 Nix Flake 配置，同时管理 NixOS 和 macOS (nix-darwin) 系统。

## 目录结构

```
├── flake.nix          # Flake 入口，声明依赖并委托 lib/ 构建
├── .sops.yaml         # sops-nix 密钥路由规则
├── Justfile           # 常用操作快捷命令
├── lib/               # 构建辅助函数（nixosSystem / darwinSystem 封装）
├── vars/              # 共享变量（用户名、SSH keys 等）
├── hosts/             # 每台机器的专属配置
├── modules/           # 系统级模块（三层：base / nixos / darwin）
├── home/              # Home Manager 用户环境（三层：base / linux / darwin）
├── overlays/          # Nixpkgs overlays（自定义包、修改、stable 通道）
├── pkgs/              # 自定义 Nix 包定义
└── secrets/           # sops-nix 加密密钥管理
```

## 快速开始

1. 编辑 `vars/default.nix` 填写用户名、邮箱、SSH keys
2. 编辑 `.sops.yaml` 填入你的 age 公钥
3. NixOS: 将 `nixos-generate-config --show-hardware-config` 输出替换到 `hosts/nixos-desktop/hardware-configuration.nix`
4. macOS: 修改 `hosts/darwin-laptop/default.nix` 中的相关配置
5. 部署: `just switch`

## 常用命令

```bash
just switch            # 构建并切换到新配置
just build             # 仅构建，不切换
just update            # 更新所有 flake inputs
just update-input xxx  # 更新单个 input
just check             # 检查 flake 语法
just fmt               # 格式化所有 nix 文件
just gc                # 垃圾回收旧 generations
```

## 架构概览

```
flake.nix
  ├─ lib/nixosSystem.nix  ── 封装 NixOS + Home Manager 集成
  ├─ lib/darwinSystem.nix ── 封装 Darwin + Home Manager 集成
  │
  ├─ hosts/nixos-desktop  ── 组合 modules/base + modules/nixos + home/base + home/linux
  └─ hosts/darwin-laptop  ── 组合 modules/base + modules/darwin + home/base + home/darwin
```

新增一台机器只需：
1. 在 `hosts/` 下创建目录
2. 在 `flake.nix` 中加一段 `mylib.nixosSystem` 或 `mylib.darwinSystem` 调用
