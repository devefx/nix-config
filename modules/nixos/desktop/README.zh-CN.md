# modules/nixos/desktop

[English](./README.md) | **简体中文**

桌面环境的系统级模块。每个 DE 都藏在 option 后面,主机按需启用。

## 目录内容

| 文件 | 选项 | 启用的内容 |
|------|------|-----------|
| `default.nix` | — | `scanPaths ./.` —— 自动扫描目录里所有文件 |
| `plasma.nix` | `modules.desktop.plasma.enable` | KDE Plasma 6(SDDM、Plasma service、pipewire、打印、显卡、系统字体) |

## 主机如何使用

**两步**。第一步,把这组加到主机的 nixos-modules:

```nix
# outputs/x86_64-linux/src/<host>.nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "modules/nixos/desktop"    # ← 这行
  "hosts/${name}"
];
```

第二步,在主机配置里启用具体 DE:

```nix
# hosts/<host>/default.nix
modules.desktop.plasma.enable = true;
```

**没第二步的话**,import `modules/nixos/desktop` 是空操作 —— 只为你启用的
东西付出代价。

## 系统级 vs 用户级

这里放的是桌面的**系统侧**:

- 显示管理器(SDDM、GDM、greetd ...)
- 合成器 / 会话(Plasma、GNOME、Hyprland ...)—— 作为 NixOS 服务
- 音频栈(pipewire)、显卡、打印、系统字体

桌面的**用户侧**(具体装什么应用、GTK/Qt 主题偏好、shell 配置)放在
`home/linux/gui/`。

## 新增一个桌面环境

1. 在此扔一个 `<de>.nix`,用 options 模式:

   ```nix
   { lib, config, pkgs, ... }:
   with lib;
   let cfg = config.modules.desktop.<de>;
   in {
     options.modules.desktop.<de> = {
       enable = mkEnableOption "<de> 桌面环境";
     };
     config = mkIf cfg.enable {
       # 显示管理器、合成器服务、音频、显卡、字体
     };
   }
   ```

2. 在 `home/linux/gui/<de>.nix` 加对应的用户侧文件
   (应用、主题、快捷键)。

3. 主机通过 `modules.desktop.<de>.enable = true;` 启用。加第二个 DE
   **不需要**动现有代码。
