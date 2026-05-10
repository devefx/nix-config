# modules/nixos

**English** | [简体中文](./README.zh-CN.md)

NixOS-specific system modules.

## Layout

```
modules/nixos/
├── default.nix    imports ./base + ../base; does NOT scan other subdirs
├── base/          auto-imported — every NixOS host gets it
├── desktop/       opt-in — wire via modules.desktop.<de>.enable
└── server/        opt-in — hosts explicitly import specific files
```

## Why base is special

`modules/nixos/default.nix` only imports `./base` and `../base` (the
cross-platform base). It intentionally **does not** `scanPaths ./.` —
that would auto-import `desktop/` and `server/` into every host, which
would force every machine to carry desktop or VM-guest configuration.

## Three patterns in practice

| Directory | Import pattern | Who decides? |
|-----------|---------------|--------------|
| `base/` | Auto via `default.nix` | Everyone (mandatory) |
| `desktop/` | Group imported by host that wants any DE, individual DEs gated by options | Host via `modules.desktop.<de>.enable = true;` |
| `server/` | Per-file explicit import in the host's module list | Host picks specific files |

## See also

- [modules/README.md](../README.md) — top-level rationale + options pattern
- [modules/nixos/desktop/README.md](./desktop/README.md) — desktop group detail
- [modules/nixos/server/README.md](./server/README.md) — server modules detail
