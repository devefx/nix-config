# overlays/

Nixpkgs overlays — 自定义和扩展 nixpkgs 包集合。

## 文件说明

| 文件 | 作用 |
|---|---|
| `default.nix` | 导出三个 overlay，由 `modules/base/nix.nix` 统一注入 nixpkgs |

## 三层 Overlay

| Overlay | 作用 | 使用方式 |
|---|---|---|
| `additions` | 将 `pkgs/` 中的自定义包注入 nixpkgs | `pkgs.my-custom-pkg` |
| `modifications` | 修改现有包（版本覆盖、补丁、编译选项） | 覆盖 `pkgs.xxx` |
| `unstable-packages` | 将 nixpkgs-stable 挂载为 `pkgs.stable` | `pkgs.stable.xxx` |

## 使用示例

由于主通道是 `nixpkgs-unstable`，当某个包在 unstable 中有问题时，可以回退到 stable：

```nix
# 在任意模块中
{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.neovim          # 来自 unstable (默认)
    pkgs.stable.firefox  # 回退到 stable 版本
  ];
}
```

## 添加自定义修改

编辑 `default.nix` 中的 `modifications` overlay：

```nix
modifications = final: prev: {
  example = prev.example.overrideAttrs (old: {
    patches = old.patches ++ [ ./my-patch.patch ];
  });
};
```
