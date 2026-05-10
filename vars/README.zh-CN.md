# vars

[English](./README.md) | **简体中文**

全局变量,注入到每个模块作为 `myvars`。

## 当前字段

| 字段 | 作用 |
|------|------|
| `username` | 主用户名 —— 驱动 home-manager 的 `users."${myvars.username}"` 和系统用户创建 |
| `userfullname` | 显示名(git 配置、user description) |
| `useremail` | git 提交邮箱,SSH key 注释等 |
| `initialHashedPassword` | 登录密码哈希 —— 用 `mkpasswd -m yescrypt --rounds=11` 生成 |
| `mainSshAuthorizedKeys` | 日常使用的 SSH 公钥 |
| `secondaryAuthorizedKeys` | 备份公钥 —— 主 key 丢失时的灾备 |

## 如何接入

`outputs/default.nix` 导入 `./vars` 后通过 `specialArgs` 注入到每个
模块作为 `myvars`。任何模块里都可以解构使用:

```nix
{ myvars, ... }:
{
  users.users."${myvars.username}".description = myvars.userfullname;
}
```

## 新增变量

在 `default.nix` 里加字段即可。一旦加上,整个 flake 的所有 NixOS /
home-manager 模块都能立刻看见。

往 `vars/` 搬字符串前先问自己:**这个字符串在多个模块中出现吗?**
如果不是,就留在本地 —— `vars/` 是给真正的全局事实(身份、密钥、
域名、时区)用的,不是什么都往里塞的杂货箱。
