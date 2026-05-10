# home/base

**English** | [简体中文](./README.zh-CN.md)

Cross-platform home-manager bits — everything here should work on both
Linux and macOS, so it can be reused from `home/linux/` and (future)
`home/darwin/` entry points.

## Structure

```
home/base/
├── home.nix     home-manager state (stateVersion, username) — always imported
├── core/        daily baseline (any host): git, starship, direnv, eza, bat, tmux, btop, yazi, cli-tools
├── tui/         dev workstation extras (reserved — add pgcli / k9s / tokei / ... here)
└── gui/         cross-platform GUI: kitty, media (ffmpeg/viu/imagemagick), dev-tools (AI agents + network)
```

Each subdirectory has a `default.nix` that `scanPaths` siblings — drop
a new `<name>.nix` into the right bucket and it is picked up automatically.

## What goes where

| Dir | Rule of thumb |
|-----|---------------|
| `core/` | **My daily baseline — every host gets this.** git, shell config, process viewer, session multiplexer, file tools. Installable without a GUI. |
| `tui/` | **Workstation extras for dev workflow.** Things only useful when I'm actively developing — git TUI, DB clients, k8s tools, language servers. Skip on pure-service hosts. |
| `gui/` | Graphical apps that run on **both** Linux and macOS. Linux-only GUI (GTK theme, fcitx5, niri config) goes to `home/linux/gui/` instead. |

## Entry points that pull from here

```
home/linux/core.nix   imports base/home.nix + base/core
home/linux/tui.nix    adds base/tui on top of core
home/linux/gui.nix    adds base/gui + linux/gui on top of tui
```

A host picks **one** of those entries in `home/hosts/<name>.nix`.
There is no `default.nix` at `home/linux/` — pick explicitly.

## `programs.<tool>` vs `home.packages`

Not all "installs" are equal — home-manager offers two mechanisms, and
picking the wrong one silently gives up features.

| Situation | Use | Example |
|-----------|-----|---------|
| home-manager has a `programs.<tool>` module | **`programs.<tool>` in its own `<tool>.nix`** | `eza.nix`, `bat.nix`, `btop.nix`, `starship.nix`, `git.nix` |
| home-manager has NO such module (pure binary) | `home.packages` inside `cli-tools.nix` | `ripgrep`, `fd`, `jq` |

`programs.<tool>.enable = true;` does more than install: it generates
config files, adds shell aliases / integrations, applies sane defaults.
Using `home.packages = [ pkgs.<tool> ]` gets you only the binary,
silently dropping those features.

Check availability via `nix repl` → `:lf <home-manager>` →
`options.programs.<tool>`, or browse
[home-manager-options.extranix.com](https://home-manager-options.extranix.com/).

**Always use `programs.<tool>` when available — even if you don't have
settings yet.** An empty `programs.<tool>.enable = true;` still beats
`home.packages` for alias / integration / default-config reasons.

## Adding a new cross-platform app

1. Decide the bucket: CLI-only → `core/`, interactive terminal → `tui/`, graphical → `gui/`.
2. Check if `programs.<app>` exists in home-manager (see above).
3. Drop `<app>.nix` with either `programs.<app>` or `home.packages`, per the table.
4. Done — no manifest to update, `scanPaths` handles it.

If the app is **Linux-only** (say, a Wayland-specific tool), put it under
`home/linux/` instead.
