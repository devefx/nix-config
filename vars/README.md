# vars

**English** | [简体中文](./README.zh-CN.md)

Global variables, injected into every module as `myvars`.

## Current fields

| Field | Purpose |
|-------|---------|
| `username` | Primary user — drives home-manager's `users."${myvars.username}"` and system user creation |
| `userfullname` | Display name (git config, user description) |
| `useremail` | Git commits, sometimes SSH key comment, etc. |
| `initialHashedPassword` | Login password hash — generate via `mkpasswd -m yescrypt --rounds=11` |
| `mainSshAuthorizedKeys` | SSH keys that get daily use |
| `secondaryAuthorizedKeys` | Backup keys — disaster recovery when the primary key is lost |

## How it's wired

`outputs/default.nix` imports `./vars` and passes the result into every
module as `myvars` via `specialArgs`. Any module can destructure:

```nix
{ myvars, ... }:
{
  users.users."${myvars.username}".description = myvars.userfullname;
}
```

## Adding a variable

Add a field to `default.nix`. Anything here is instantly visible to
every NixOS / home-manager module in the flake.

Before moving a string into `vars/`, ask: **does it appear in more than
one module?** If not, keep it local — `vars/` is for truly global
facts (identity, keys, domain, timezone), not a catch-all config bag.
