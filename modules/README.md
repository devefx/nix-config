# modules

**English** | [简体中文](./README.zh-CN.md)

System-level modules (NixOS / nix-darwin). The place for anything that
needs to go into `/etc`, `/nix/store`-wide settings, systemd services,
kernel / boot, or system-wide package sets.

User-level stuff (apps installed per user, dotfiles, themes) belongs in
`home/`, not here.

## Layout

```
modules/
├── base/          cross-platform: nix settings, users, ...
└── nixos/
    ├── base/      NixOS mandatory base (auto-imported)
    ├── desktop/   desktop group — opt-in via modules.desktop.<de>.enable
    └── server/    server modules — explicitly imported by server-ish hosts
```

When a macOS host is added later, a `modules/darwin/` sibling will appear.

## Two import patterns

Depending on whether a subdirectory is "everyone needs it" or
"opt-in per host", it's plugged in differently.

| Pattern | Where | How it's loaded |
|---------|-------|-----------------|
| **Auto-imported** | `modules/base/`, `modules/nixos/base/` | Every host that imports `modules/nixos` gets them automatically via `modules/nixos/default.nix` |
| **Explicit import** | `modules/nixos/server/<file>.nix` | The host adds the specific file to its `nixos-modules` list |
| **Options-gated** | `modules/nixos/desktop/` | Imported group-wide, but each feature gated behind `modules.desktop.<de>.enable` |

## Options pattern (the right way to extend)

Instead of a new file doing unconditional work, define an option and
gate the config:

```nix
{ lib, config, ... }:
with lib;
let cfg = config.modules.<area>.<feature>;
in {
  options.modules.<area>.<feature>.enable = mkEnableOption "<feature>";
  config = mkIf cfg.enable {
    # actual configuration here
  };
}
```

Hosts then opt in:

```nix
# hosts/<host>/default.nix
modules.<area>.<feature>.enable = true;
```

This keeps unused features at zero cost and avoids "mass import"
side-effects.

## Adding a module

1. Pick the bucket:
   - Cross-platform (also meaningful on macOS) → `modules/base/`
   - NixOS-specific base (every host needs it) → `modules/nixos/base/`
   - Desktop environment or GUI-related system service → `modules/nixos/desktop/`
   - Server-only (virtualization guest, k8s node, ...) → `modules/nixos/server/`
2. Use the options pattern above unless the module is truly always-on base.
3. Hosts enable via `modules.<area>.<feature>.enable = true;`.
