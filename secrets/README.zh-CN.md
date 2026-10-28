# secrets

[English](./README.md) | **简体中文**

agenix 接线: 密文在私有仓库 `devefx/nix-secrets` 里(flake input
`mysecrets`), 本目录只声明哪些文件要解密、给谁。

## 创建与修改

| Recipe                        | 是否解密旧值 | sudo | 适用           |
| ----------------------------- | ------------ | ---- | -------------- |
| `just secrets-replace <name>` | 否           | 否   | 新建或整份替换 |
| `just secrets-edit <name>`    | 是           | 是   | 修改已有的值   |

```bash
just secrets-replace my-service-token < plaintext
printf '%s' "$TOKEN" | just secrets-replace my-service-token
EDITOR=code just secrets-edit my-service-token
```

多行值也可以 —— 比如一整份 systemd `EnvironmentFile`:

```bash
just secrets-replace pi-web <<'EOF'
PI_WEB_PASSWORD=correct horse battery staple
PI_WEB_ALLOWED_HOSTS=pi.example.com
EOF
```

解析这份文件的是 systemd 而不是 shell: 不能写 `export`、不展开 `$VAR`、不支持续行, 而 `KEY = value`
会把空格带进 key。值里含空格或 `#` 时用引号包起来。

## 使用

```bash
cd ../nix-secrets && git add my-service-token.age && git commit -m "Add token" && git push
cd ../nix-config && just secrets-lock   # mysecrets 锁定的是 commit, 不是工作区
```

然后在 [`nixos.nix`](./nixos.nix) 里声明, 并在主机上打开开关:

```nix
# secrets/nixos.nix
age.secrets.my-service-token = {
  file = "${mysecrets}/my-service-token.age";
  owner = myvars.username;
  mode = "0600";
};

# hosts/faex1/default.nix
modules.secrets.myService.enable = true;
```

消费方读解密后的路径 —— `/run/agenix/<name>`, tmpfs, 仅属主可读:

```nix
modules.aiAgents.piWeb.environmentFile = osConfig.age.secrets.pi-web.path;
```

最后 `just switch`。

## 现有 secret

`smb-credentials` 和 `smb-credentials-wd20t`(SMB 挂载)、`hf-token`(`HF_TOKEN`)、`pi-web`(Pi
Web用户服务的 `EnvironmentFile`)。收件人只有本机的 SSH key —— `just host-age` 打印它,
`NIX_SECRETS_EXTRA_RECIPIENTS` 可以在单次运行时追加更多。

## 注意

- 没提交的 `.age` 构建看不见: `flake = false` 读的是 git, 不是工作区。
- 推了密文但没跑 `just secrets-lock`, 构建仍用旧密文。
- 别对解密后的路径用 `builtins.readFile` —— 那会把明文复制进 `/nix/store`。
- `/run/agenix` 是 tmpfs, 每次 activation 重建。

## 排查

```bash
journalctl -b | grep -B2 -A5 agenix
AGE=$(nix build --no-link --print-out-paths nixpkgs#age)/bin/age
cd ../nix-secrets && sudo "$AGE" -d -i /etc/ssh/ssh_host_ed25519_key pi-web.age
```
