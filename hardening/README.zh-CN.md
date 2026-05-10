# Hardening(安全加固)

[English](./README.md) | **简体中文**

三层**可选启用**(opt-in)的安全加固机制。任何一层在你没把它接入主机模块前
都不会生效。

## 三层机制

### 1. 系统级加固(`profiles/`)
导入 NixOS 官方 `profiles/hardened.nix`,再外加几项(关闭 coredump 等)。

> **注意**:hardened profile 很激进,可能破坏:
> - 游戏(反作弊、GPU 性能)
> - 虚拟化(KVM/libvirt 某些场景)
> - 某些专有驱动 / 固件
>
> 除非你清楚每一项代价,否则别随便开。

### 2. 单应用沙箱:Nixpak(`nixpaks/`)
基于 [nixpak](https://github.com/nixpak/nixpak) 的声明式 bubblewrap 沙箱。
沙箱化后的应用暴露在 `pkgs.nixpaks.<name>`。

**复用子模块**放在 `nixpaks/modules/` — 每个沙箱化应用从这里 import,
避免每个应用重写 dbus 策略 / GPU / 字体绑定:

| 模块 | 职责 |
|------|------|
| `common.nix` | dbus 策略、XDG Portal 访问、MPRIS 多媒体、mesa 着色器缓存、fontconfig — 所有 GUI 应用都要 |
| `gui-base.nix` | GPU、locale、GTK、鼠标/图标主题、Wayland socket、XDG_RUNTIME_DIR |
| `network.nix` | 绑定 `/etc/resolv.conf` + SSL 证书 + 开启网络 |

**新增一个沙箱应用**:
1. 在 `nixpaks/` 下新建 `<app>.nix`,按需导入子模块:
   ```nix
   imports = [ ./modules/gui-base.nix ./modules/common.nix ./modules/network.nix ];
   ```
2. 在 `nixpaks/default.nix` 的 overlay 里注册一行。
3. 在任何需要的地方用 `pkgs.nixpaks.<app>` 引用。

本仓库的 `hardening/nixpaks/firefox.nix` 就是完整可运行示例 ——
给 Firefox 装上 GPU / wayland / pipewire 套接字,只对 `~/.mozilla` 和
XDG 用户目录开放读写。被 `home/linux/gui/base/firefox.nix` 引用。

### 3. 单应用沙箱:原生 Bubblewrap(`bwraps/`)
直接写 `extraBwrapArgs` — 适合 AppImage 或者 nixpak 的 DSL 包装反而碍事的场景。
暴露在 `pkgs.bwraps.<name>`。

## 如何在主机启用

编辑 `outputs/x86_64-linux/src/<host>.nix`:

```nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "hosts/${name}"
  # overlay 层(安全 — 只注册 pkgs.nixpaks / pkgs.bwraps 命名空间,
  # 不引用任何应用时 0 开销)
  "hardening/nixpaks"
  "hardening/bwraps"
  # 系统级加固(可选 — 会影响兼容性,先读完 profile 再打开)
  # "hardening/profiles"
];
```

然后像普通包那样引用:

```nix
environment.systemPackages = [ pkgs.nixpaks.firefox ];
# 或在 home-manager 里:
home.packages = [ pkgs.bwraps.wechat ];
```

## 为什么这么设计

- **overlay 而不是无条件 import** — 沙箱层只往 `pkgs` 加命名空间,没副作用。
  不引用的应用零开销。
- **三种机制按应用选** — 行为规矩的应用用 nixpak;AppImage 用原生 bwrap;
  整机可信任场景才开 hardened profile。

## 参考

- [nixpak](https://github.com/nixpak/nixpak)
- [bubblewrap](https://github.com/containers/bubblewrap)
- [NixOS hardened profile](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/profiles/hardened.nix)
- 可运行示例:`ryan4yin-nix-config/hardening/`
