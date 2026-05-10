# lib

[English](./README.md) | **简体中文**

工厂函数和工具辅助库。

## 目录内容

| 文件 | 作用 |
|------|------|
| `default.nix` | 入口 —— 通过 specialArgs 暴露为全局 `mylib.*` |
| `nixosSystem.nix` | 工厂函数,封装 `nixpkgs.lib.nixosSystem` 并接入 home-manager |
| `attrs.nix` | attrset 工具占位,需要时往里加 list/attr 辅助函数 |

## 关键导出(任何模块里都可以 `mylib.<name>` 访问)

| 导出 | 作用 |
|------|------|
| `mylib.nixosSystem` | 工厂函数 —— 主机文件传 `{ nixos-modules, home-modules, ... }` 给它 |
| `mylib.scanPaths path` | 返回 `<path>/` 下所有 `.nix` 文件和子目录(排除 `default.nix`)—— 模块的 `default.nix` 靠它自动扫描 |
| `mylib.relativeToRoot` | 把 `"modules/nixos"` 这种字符串转成绝对模块路径 |
| `mylib.attrs` | attrset 工具 |

## 为什么要用工厂函数

主机文件只负责**拼 list**:`nixos-modules` + `home-modules`,然后把
list 丢给 `mylib.nixosSystem`。nixpkgs / home-manager 的对接细节只在
一个地方,主机文件就能只有几十行。

以后加新平台(darwin、riscv 等)或新部署模式(colmena、nixos-generators
生成镜像)时,在这里**加新的工厂函数**,而不是在每个主机文件里重复 wiring。

## 新增工具函数

扔一个 `<name>.nix` 导出辅助函数,在 `default.nix` 里加一行引用,
全项目就能 `mylib.<name>` 用到了。
