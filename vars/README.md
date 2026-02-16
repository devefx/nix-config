# vars/

集中存放所有主机共享的变量，避免用户信息散落在各处。

## 文件说明

| 文件 | 作用 |
|---|---|
| `default.nix` | 导出共享变量 attribute set，包括用户名、邮箱、SSH 公钥等 |

## 使用方式

所有模块通过 `specialArgs` 中的 `myvars` 访问这些变量：

```nix
# 在任意模块中
{ myvars, ... }: {
  users.users.${myvars.username} = { ... };
  programs.git.userEmail = myvars.useremail;
}
```

## 当前变量

| 变量 | 说明 |
|---|---|
| `username` | 系统用户名，用于创建用户和 Home Manager |
| `userfullname` | 全名，用于 git config 等 |
| `useremail` | 邮箱，用于 git config 等 |
| `sshAuthorizedKeys` | SSH 公钥列表，用于 authorized_keys |

## 扩展

随着配置增长，可以在此添加更多共享变量，例如：
- `networking.nix` — 网络相关变量 (DNS, proxy 等)
- 默认编辑器、时区、语言等偏好设置
