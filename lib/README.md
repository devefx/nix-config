# lib/

构建辅助函数，封装了 NixOS 和 macOS 系统的创建逻辑。

## 文件说明

| 文件 | 作用 |
|---|---|
| `default.nix` | 导出所有 helper 函数，供 `flake.nix` 通过 `mylib.xxx` 调用 |
| `nixosSystem.nix` | 封装 `nixpkgs.lib.nixosSystem`，自动集成 Home Manager 作为 NixOS module |
| `darwinSystem.nix` | 封装 `nix-darwin.lib.darwinSystem`，自动集成 Home Manager 作为 Darwin module |

## 设计意图

避免在 `flake.nix` 中重复编写 Home Manager 集成样板代码。每个封装函数接受：

- `system` — 目标架构 (如 `x86_64-linux`, `aarch64-darwin`)
- `specialArgs` — 传递给所有模块的额外参数 (inputs, myvars 等)
- `nixos-modules` / `darwin-modules` — 系统级模块列表
- `home-modules` — Home Manager 模块列表 (可选)

调用示例：

```nix
mylib.nixosSystem {
  system = "x86_64-linux";
  inherit specialArgs;
  nixos-modules = [ ./hosts/my-host ./modules/base ./modules/nixos ];
  home-modules = [ ./home/base ./home/linux ];
};
```

## 扩展

如需支持更多平台或部署方式，可在此添加新的封装函数，例如：
- `colmenaSystem.nix` — 用于 Colmena 远程部署
- `nixosInstaller.nix` — 用于生成安装 ISO
