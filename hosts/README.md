# hosts/

每台机器的专属配置，一个目录对应一台主机。

## 目录结构

```
hosts/
├── nixos-desktop/               # NixOS 桌面主机
│   ├── default.nix              # 主机入口：hostname、用户、服务
│   └── hardware-configuration.nix  # 硬件配置（由 nixos-generate-config 生成）
└── darwin-laptop/               # macOS 笔记本
    └── default.nix              # 主机入口：nix-daemon、用户、Homebrew
```

## 设计原则

- 每台主机一个目录，目录名即主机标识
- `default.nix` 是入口文件，只包含**该主机特有**的配置
- 通用配置放在 `modules/` 和 `home/` 中，主机通过 `flake.nix` 组合引用
- NixOS 主机需要 `hardware-configuration.nix`，通过 `nixos-generate-config --show-hardware-config` 生成

## 新增主机

1. 创建 `hosts/<hostname>/default.nix`
2. (NixOS) 添加 `hardware-configuration.nix`
3. 在 `flake.nix` 中加一段构建调用：

```nix
nixosConfigurations.<hostname> = mylib.nixosSystem {
  system = "x86_64-linux";
  inherit specialArgs;
  nixos-modules = [ ./hosts/<hostname> ./modules/base ./modules/nixos ./secrets ];
  home-modules = [ ./home/base ./home/linux ];
};
```

## 主机专属配置示例

主机目录中可以按需拆分文件：

```
hosts/my-workstation/
├── default.nix                  # 入口
├── hardware-configuration.nix   # 硬件
├── nvidia.nix                   # GPU 驱动
├── networking.nix               # 特殊网络配置
└── home.nix                     # 主机专属的 HM 配置
```
