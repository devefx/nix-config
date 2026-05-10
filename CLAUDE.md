# CLAUDE.md — nix-config

## 参考项目

本项目的框架、结构、命名约定均参考自:

**`/Users/yoke/Documents/Projects/ryan4yin-nix-config`**

原作: https://github.com/ryan4yin/nix-config

如遇到结构、模块组织、工厂函数用法等问题,优先查阅参考项目对应位置。

## 框架要点(必须遵守)

本仓库保留参考项目的四个核心机制,修改时不要破坏它们:

1. **haumea 自动加载** — `outputs/<system>/src/*.nix` 扔进去即生效,主机定义通过
   `haumea.lib.load` 合并。新增主机 = 新增一个 src 文件,不需要手动 import。
2. **工厂函数** — 主机文件只拼 `nixos-modules` / `home-modules` 列表,
   真正的 `nixpkgs.lib.nixosSystem { ... }` 封装在 `lib/nixosSystem.nix`。
   不要绕过工厂直接写 nixosSystem。
3. **specialArgs 注入** — `outputs/default.nix` 通过 `genSpecialArgs` 注入
   `mylib / myvars / pkgs-stable`,全项目模块都能拿到。不要在模块里重复
   `inherit inputs` 或到处硬编码字符串。
4. **options 开关式模块** — 共享模块定义 `options.modules.xxx.enable`,
   主机通过 `modules.xxx.enable = true;` 启用。不要用无条件 `imports` 硬塞。

## 目录职责

| 目录 | 职责 |
|------|------|
| `flake.nix` | 只声明 inputs 和 `outputs = import ./outputs` |
| `outputs/` | 按 system 聚合,haumea 自动加载 |
| `lib/` | 工厂函数 + `scanPaths` / `relativeToRoot` 等工具 |
| `vars/` | 全局变量(username、邮箱、SSH key、密码哈希) |
| `hosts/<name>/` | 一台机器的硬件/disko/主机特有配置 |
| `modules/base/` | 跨平台共享模块 |
| `modules/nixos/` | NixOS 专属模块 |
| `home/base/` | home-manager 跨平台共享 |
| `home/linux/` | home-manager Linux 特有 |
| `home/hosts/<name>.nix` | 一个用户在一台机器上的 home 配置 |
| `hardening/nixpaks/` | Nixpak 单应用沙箱,暴露到 `pkgs.nixpaks.<app>` |
| `hardening/bwraps/` | 原生 Bubblewrap 单应用沙箱,暴露到 `pkgs.bwraps.<app>` |
| `hardening/profiles/` | NixOS hardened profile 系统级加固(opt-in,激进) |

## 与参考项目的差异(精简掉的部分)

本仓库作为**最小骨架**起步,以下参考项目的部分**暂未包含**,需要时再从参考项目按需移植:

- `nix-darwin` / `home/darwin`(没有 Mac)
- `colmena`(远程 SSH 部署)
- `lib/genK3s*` / `lib/genKubeVirt*`(k8s / 虚拟机工厂)
- `nixpkgs-master / nixpkgs-patched / nixpkgs-2505`(多分支 nixpkgs,暂只保留
  `nixpkgs` + `nixpkgs-stable`)
- `agenix / disko / preservation / lanzaboote`(加密、分区、无状态、SecureBoot)
- `catppuccin / nix-gaming / aagl`(主题 & 游戏)
- `nixos-generators`(多镜像格式)
- `nixos-apple-silicon`(M 系列芯片)

移植原则:**从参考项目对应目录整块复制进来**,然后裁剪掉作者个人信息
(用户名、邮箱、SSH key、主机名、私有 inputs `mysecrets / my-asahi-firmware / wallpapers / nur-ryan4yin`)。

## 工作流约定

- 变更前先阅读参考项目对应位置,保持命名一致(`modules.desktop.xxx.enable` 这种风格)
- 新增主机:在 `outputs/x86_64-linux/src/` 加文件 → 建 `hosts/<name>/` →
  建 `home/hosts/<name>.nix` → `just build <name>` 验证 → `just switch <name>`
- 提交前跑 `nix flake check`(触发 pre-commit hooks: nixfmt + typos + prettier)
- 不要在 master 上直接提交,按功能开分支
