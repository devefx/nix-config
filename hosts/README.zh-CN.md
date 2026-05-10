# hosts

[English](./README.md) | **简体中文**

每台主机的系统级配置 —— 硬件、hostname、disko 布局,以及所有**机器间
确实不同**的内容。

## 目录布局

```
hosts/
├── <主机>/
│   ├── default.nix              hostName + 主机专属设置
│   ├── hardware-configuration.nix  由 `nixos-generate-config` 生成
│   └── ... (可选:disko.nix、netdev-mount.nix、secureboot.nix 等)
└── ...
```

当前主机:`faex1`(物理桌面机)、`pve-lab1`(PVE 沙盒 VM)。

## 什么放这里 vs 什么放 `modules/`

| 放这里 | 放 `modules/` |
|--------|--------------|
| `networking.hostName` | 任何能被第二台主机复用的东西 |
| `hardware-configuration.nix`(生成的) | 全系统功能开关 |
| 磁盘布局 / disko 配置 | 桌面 / server 基础设施 |
| 主机专属防火墙规则 / 静态 IP | 按用户装的应用清单(那些放 `home/`) |
| 启用哪些 options:`modules.desktop.plasma.enable = true;` | KDE 的具体配置本体 |

经验法则:**如果这个文件复制到另一台新主机也能用,那就不该放这里** ——
把可复用部分抽到 `modules/` 里,藏在 option 后面。

## 新增主机

1. 建 `hosts/<name>/default.nix`:
   ```nix
   {
     imports = [ ./hardware-configuration.nix ];
     networking.hostName = "<name>";
     system.stateVersion = "25.11";
     # 按需开 options
     # modules.desktop.plasma.enable = true;
   }
   ```
2. 在目标机器上生成 `hardware-configuration.nix`:
   `sudo nixos-generate-config --dir /tmp/hw`,把它复制到 `hosts/<name>/`。
3. 建对应的 output 声明 `outputs/x86_64-linux/src/<name>.nix`
   (见 [outputs/README.zh-CN.md](../outputs/README.zh-CN.md))。
4. 建 home-manager 入口 `home/hosts/<name>.nix`,从
   `core.nix` / `tui.nix` / `gui.nix` 里**选一个**
   (见 [home/linux/README.zh-CN.md](../home/linux/README.zh-CN.md))。
