# modules/base

[English](./README.md) | **简体中文**

跨平台系统模块 —— NixOS 和(未来的)nix-darwin 主机共用。通过
`modules/nixos/default.nix` 的 `imports = [ ./base ../base ]` 自动导入。

## 目录内容

| 文件 | 作用 |
|------|------|
| `default.nix` | `scanPaths ./.` —— 自动扫描同级 `.nix` 文件 |
| `nix.nix` | nix daemon 设置:experimental features、substituters、GC、trusted users |
| `users.nix` | 用户描述 + SSH 公钥(主 + 备份) |

## 放这里的文件必须满足的规则

- **Linux 和 macOS 必须都能跑。** 如果是 NixOS 专属的内容(systemd
  units、内核模块、`boot.*` 相关),放到 `modules/nixos/base/`。
- **无条件生效。** 这里的内容是**所有主机都强制启用**的。带开关的功能
  不应该放在这里,应该用同级目录里的 options 模式。

## 新增文件

扔一个 `<name>.nix` 进来,`scanPaths` 会自动识别,无需改任何 manifest。
