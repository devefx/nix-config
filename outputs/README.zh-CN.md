# outputs

[English](./README.md) | **简体中文**

Flake 输出聚合层。`flake.nix` 只有一行 `outputs = import ./outputs`
把一切都委托到这里。

## 目录结构

```
outputs/
├── default.nix              顶层:注入 specialArgs、跨架构聚合
└── x86_64-linux/
    ├── default.nix          haumea 加载 ./src,合并 nixosConfigurations / packages
    └── src/
        ├── faex1.nix        一个文件 = 一台主机
        └── pve-lab1.nix
```

## 工作原理

1. `default.nix` 构造 `genSpecialArgs` —— 注入给每个 NixOS / home-manager
   模块的"万能参数包":`mylib`、`myvars`、`pkgs-stable`,加上所有 flake input。
2. 对每个支持的 system(当前只有 `x86_64-linux`)委托到
   `outputs/<system>/default.nix`。
3. 每个 system 的 `default.nix` 用 **haumea** 自动加载 `./src/` 下所有
   `.nix` 文件。每个文件返回一个小 attrset 带 `nixosConfigurations.<name>`
   (可选 `packages.<name>`),haumea 合并它们。
4. 顶层把各 system 的结果合成最终的 flake 输出
   (`nixosConfigurations`、`packages`、`checks`、`devShells`、`formatter`)。

## 新增主机

往 `outputs/x86_64-linux/src/<host>.nix` 扔一个文件。模板:

```nix
{ inputs, lib, myvars, mylib, system, genSpecialArgs, ... }@args:
let
  name = "<host>";
  modules = {
    nixos-modules = map mylib.relativeToRoot [
      "modules/nixos"
      "hosts/${name}"
      # ...按需加沙箱、桌面、server 模块
    ];
    home-modules = map mylib.relativeToRoot [
      "home/hosts/${name}.nix"
    ];
  };
in {
  nixosConfigurations."${name}" = mylib.nixosSystem (modules // args);
}
```

haumea 会自动识别 —— **不用改任何 manifest**。

## 新增架构平台

加一个 `outputs/<arch>/` 目录,带自己的 `default.nix` + `src/`,
然后在 `outputs/default.nix` 的 `nixosSystems` / `darwinSystems`
映射里注册一行。
