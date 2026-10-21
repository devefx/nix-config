# modules/base

**English** | [简体中文](./README.zh-CN.md)

Cross-platform system modules — shared between NixOS and (future) nix-darwin hosts. Auto-imported
via `modules/nixos/default.nix`'s `imports = [ ./base ../base ]`.

## Contents

| File           | Purpose                                                                     |
| -------------- | --------------------------------------------------------------------------- |
| `default.nix`  | `scanPaths ./.` — picks up every `.nix` sibling automatically               |
| `nix.nix`      | Nix daemon settings: experimental features, substituters, GC, trusted users |
| `fonts.nix`    | System font bundle, gated behind `modules.desktop.fonts.enable`             |
| `security.nix` | System trust store — installs the local mkcert development CA               |

Users and SSH keys are **not** here: they live in `modules/nixos/base/user-group.nix`, because
`users.users.*` handling is NixOS-specific.

## Rules for files here

- **Must work on both NixOS and macOS.** If it's NixOS-specific (systemd units, kernel modules,
  `boot.*` options), move it to `modules/nixos/base/`.
- **Always-on.** Everything here is mandatory for every host — don't add features that should be
  opt-in, use the `options` pattern in a sibling directory instead.

## Adding a file

Drop `<name>.nix` here. `scanPaths` picks it up automatically, no manifest to edit.
