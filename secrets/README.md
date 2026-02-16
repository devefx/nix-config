# secrets/

使用 [sops-nix](https://github.com/Mic92/sops-nix) 管理加密密钥。

## 文件说明

| 文件 | 作用 |
|---|---|
| `nixos.nix` | NixOS 模块，导入 `sops-nix.nixosModules.sops`，使用 SSH host key 派生 age key |
| `darwin.nix` | macOS 模块，导入 `sops-nix.darwinModules.sops`，使用 `~/.config/sops/age/keys.txt` |
| `secrets.yaml` | SOPS 加密的密钥文件（提交到 git 是安全的） |

> **注意**: NixOS 和 Darwin 使用不同的 sops-nix 模块，因此拆分为两个文件。
> 在 `flake.nix` 中 NixOS 主机引用 `./secrets/nixos.nix`，Darwin 主机引用 `./secrets/darwin.nix`。

## 工作流程

### 初始设置

1. **生成 age 密钥**（如果还没有）：

```bash
age-keygen -o ~/.config/sops/age/keys.txt
# 记下输出的 public key: age1xxxx...
```

2. **配置 `.sops.yaml`**（项目根目录）— 填入你的 age 公钥

3. **创建并加密密钥文件**：

```bash
sops secrets/secrets.yaml
# 会打开编辑器，填入明文密钥，保存后自动加密
```

### 添加新密钥

1. 在 `secrets/nixos.nix`（或 `darwin.nix`）中声明：

```nix
sops.secrets.my-api-key = {};
sops.secrets."database/password" = {
  owner = "postgres";
};
```

2. 在 `secrets.yaml` 中添加对应的密钥值：

```bash
sops secrets/secrets.yaml
# 添加:
# my-api-key: sk-xxxx
# database:
#     password: super-secret
```

3. 在其他模块中引用（密钥在运行时解密到 `/run/secrets/`）：

```nix
{ config, ... }: {
  services.my-app = {
    passwordFile = config.sops.secrets.my-api-key.path;
  };
}
```

## 注意事项

- `secrets.yaml` 加密后可安全提交到 git
- NixOS 默认使用主机 SSH key (`/etc/ssh/ssh_host_ed25519_key`) 派生 age key
- macOS 需要手动设置 `SOPS_AGE_KEY_FILE` 或在 `default.nix` 中指定 `age.keyFile`
- 更换机器后需要用新主机的公钥重新加密：`sops updatekeys secrets/secrets.yaml`
