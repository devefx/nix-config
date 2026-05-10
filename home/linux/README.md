# home/linux

**English** | [简体中文](./README.zh-CN.md)

Linux-specific home-manager configuration, plus the entry points a host
imports.

## Contents

```
home/linux/
├── core.nix    entry: base/home.nix + base/core
├── tui.nix     entry: core + base/tui
├── gui.nix     entry: tui + base/gui + linux/gui
└── gui/        Linux-only GUI user bits
    ├── default.nix   scanPaths — picks up siblings automatically
    ├── base/         DE-agnostic (applies to any compositor/DE)
    │   ├── gtk.nix       GTK cursor / font (so GTK apps blend with Plasma)
    │   ├── firefox.nix   Firefox (sandboxed via nixpak — hardening/nixpaks/firefox.nix)
    │   ├── chrome.nix    Google Chrome (unfree; has its own built-in sandbox)
    │   ├── fcitx5.nix    Chinese input method (Pinyin / Shuangpin / Wubi)
    │   └── lutris.nix    Linux game launcher (Wine / Proton / GOG / ...)
    └── plasma.nix   Plasma / KDE user apps: kate, ark, gwenview, ...
```

**No `default.nix` at this level.** Hosts pick one of the three `.nix`
entries explicitly.

## Why three entries

Different hosts want different levels:

- A service-only server (nginx / postgres box — no dev work) wants
  `core.nix` — daily baseline (git, tmux, btop, direnv) without dev
  extras.
- A dev-active VM / workstation without GUI wants `tui.nix` — reserves
  the layer for future dev-tools (pgcli, k8s clients, ...); currently
  empty.
- A desktop or GUI-enabled VM (`faex1`, `pve-lab1`) wants `gui.nix` —
  everything including KDE apps and GTK theming.

Layers stack: **core ⊂ tui ⊂ gui**. If a host uses `gui.nix`, it
automatically gets everything in `tui.nix` and `core.nix` too.

## `linux/gui/` vs `base/gui/`

| Directory | Content |
|-----------|---------|
| `home/base/gui/` | Cross-platform GUI apps — VS Code, Obsidian — good home-manager support on both OSes |
| `home/linux/gui/` | Linux-only GUI bits — KDE apps, GTK theme, fcitx5, niri keybinds, etc. |

When adding a new GUI app, ask: **does it run on macOS too?** If yes →
`home/base/gui/`; if no → `home/linux/gui/`.

## Adding files

Drop a `.nix` into the right bucket — `scanPaths` in the `default.nix`
picks it up automatically. No manifest to edit.
