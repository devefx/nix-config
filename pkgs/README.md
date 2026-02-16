# pkgs/

自定义 Nix 包定义。这里定义的包通过 `overlays/default.nix` 的 `additions` overlay 注入 nixpkgs，可在所有模块中以 `pkgs.xxx` 方式使用。

## 文件说明

| 文件 | 作用 |
|---|---|
| `default.nix` | 包注册表，以 attribute set 形式导出所有自定义包 |

## 添加自定义包

1. 创建包目录：

```
pkgs/
├── default.nix
└── my-tool/
    └── default.nix
```

2. 编写包定义 (`pkgs/my-tool/default.nix`)：

```nix
{ lib, stdenv, fetchFromGitHub, ... }:
stdenv.mkDerivation {
  pname = "my-tool";
  version = "1.0.0";
  src = fetchFromGitHub { ... };
  # ...
}
```

3. 注册到 `pkgs/default.nix`：

```nix
pkgs: {
  my-tool = pkgs.callPackage ./my-tool {};
}
```

4. 在任意模块中使用：

```nix
{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.my-tool ];
}
```

## 构建与测试

```bash
nix build .#my-tool    # 构建单个包
nix run .#my-tool      # 构建并运行
nix flake show         # 查看所有导出的包
```
