# home

[English](./README.md) | **简体中文**

用户级配置,由 home-manager 管理。按用户装的应用、dotfiles、主题、
shell 配置 —— 原则上不需要 root 就能装的东西都在这里。

系统级内容(服务、内核、启动、全系统软件包)属于 `modules/`,**不是这里**。

## 目录布局

```
home/
├── base/          跨平台(Linux + 未来的 macOS)—— home、core、tui、gui
├── linux/         Linux 专属 —— core/tui/gui 入口 + linux/gui 子目录
└── hosts/         一台主机一个入口:从 core / tui / gui 里选一个
```

## 三层入口

每个主机的 `home/hosts/<name>.nix` **选一个**入口:

| 入口 | 拉进来的内容 | 典型主机 |
|------|------------|---------|
| `home/linux/core.nix` | `base/home.nix` + `base/core`(tmux、btop、git 等) | 只跑服务的服务器、最小化容器 |
| `home/linux/tui.nix` | core + `base/tui`(未来的 dev 工具 —— 当前为空) | 开发活跃的 VM / 工作站(无需 GUI) |
| `home/linux/gui.nix` | tui + `base/gui` + `linux/gui` | 桌面 + 有 GUI 的 VM(`faex1`、`pve-lab1`) |

叠加关系:**core ⊂ tui ⊂ gui**。`home/linux/` 下**没有** `default.nix` ——
主机必须显式选择。

## 延伸阅读

- [home/base/README.zh-CN.md](./base/README.zh-CN.md) —— 跨平台规则,`core/` vs `tui/` vs `gui/` 怎么选
- [home/linux/README.zh-CN.md](./linux/README.zh-CN.md) —— 入口细节、`linux/gui/` vs `base/gui/`
