# home

**English** | [简体中文](./README.zh-CN.md)

User-level configuration, managed by home-manager. Per-user apps,
dotfiles, themes, shell config — anything that could in principle be
installed without root.

System-level stuff (services, kernel, boot, system-wide packages)
belongs in `modules/`, not here.

## Layout

```
home/
├── base/          cross-platform (Linux + future macOS) — home, core, tui, gui
├── linux/         Linux-specific — core/tui/gui entry points + linux/gui subdir
└── hosts/         per-host entry: pick one of core / tui / gui
```

## Three-tier entry points

Each host's `home/hosts/<name>.nix` picks **one** of:

| Entry | What it pulls in | Typical host |
|-------|------------------|--------------|
| `home/linux/core.nix` | `base/home.nix` + `base/core` (tmux, btop, git, ...) | Service-only servers, minimal containers |
| `home/linux/tui.nix` | core + `base/tui` (future dev tools — currently empty) | Dev-active VMs / workstations (no GUI needed) |
| `home/linux/gui.nix` | tui + `base/gui` + `linux/gui` | Desktops + GUI VMs (`faex1`, `pve-lab1`) |

Layers stack: **core ⊂ tui ⊂ gui**. No `default.nix` in `home/linux/` —
the host must pick explicitly.

## See also

- [home/base/README.md](./base/README.md) — cross-platform rules, what goes in `core/` vs `tui/` vs `gui/`
- [home/linux/README.md](./linux/README.md) — entry point detail, `linux/gui/` vs `base/gui/`
