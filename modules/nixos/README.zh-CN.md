# modules/nixos

[English](./README.md) | **简体中文**

NixOS 专属系统模块。

## 目录布局

```
modules/nixos/
├── default.nix    导入 ./base + ../base;不扫描其他子目录
├── base/          自动导入 —— 所有 NixOS 主机强制启用
├── desktop/       opt-in —— 通过 modules.desktop.<de>.enable 打开
└── server/        opt-in —— 主机显式 import 具体文件
```

## 为什么 base 是特殊的

`modules/nixos/default.nix` **只** 导入 `./base` 和 `../base`(跨平台
base),**刻意没有**用 `scanPaths ./.`—— 否则每台主机都会被强塞
`desktop/` 和 `server/` 的内容,桌面机被迫带 server 配置、服务器被迫
带 DE 配置,这就乱了。

## 三种实战模式

| 目录 | 导入方式 | 谁决定是否启用 |
|------|---------|--------------|
| `base/` | 通过 `default.nix` 自动 | 所有人(强制) |
| `desktop/` | 想要任何 DE 的主机整组 import,具体 DE 用 options 开关 | 主机:`modules.desktop.<de>.enable = true;` |
| `server/` | 主机 modules 列表里**按文件**显式 import | 主机挑具体文件 |

## 延伸阅读

- [modules/README.md](../README.md) —— 顶层设计原则 + options 模式
- [modules/nixos/desktop/README.md](./desktop/README.md) —— desktop 组细节
- [modules/nixos/server/README.md](./server/README.md) —— server 模块细节
