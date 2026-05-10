# nix-config

**English** | [简体中文](./README.zh-CN.md)

Personal NixOS configuration. Framework modeled after
[ryan4yin/nix-config](https://github.com/ryan4yin/nix-config).

## Layout

```
flake.nix                     flake entry; outputs = import ./outputs
outputs/                      per-system aggregation (haumea auto-loads src/)
lib/                          factory functions (nixosSystem, scanPaths, ...)
vars/                         global variables (username, keys, ...)
hosts/<name>/                 host-specific: hardware, disko, etc.
modules/base/                 cross-platform system modules
modules/nixos/base/           NixOS mandatory base (auto-imported)
modules/nixos/desktop/        NixOS desktop group (opt-in: modules.desktop.<de>.enable)
modules/nixos/server/         NixOS server modules (opt-in per host)
home/base/home.nix            home-manager state (stateVersion, username)
home/base/core/               daily baseline: git, ssh, starship, direnv, eza, bat, tmux, btop, yazi, cli tools
home/base/tui/                dev workstation extras (reserved — add pgcli / k9s / tokei / ... here)
home/base/gui/                cross-platform GUI: kitty, media (ffmpeg/imagemagick/...), dev-tools (AI agents)
home/linux/core.nix           Linux entry: CLI-only
home/linux/tui.nix            Linux entry: core + TUI tools
home/linux/gui.nix            Linux entry: core + TUI + GUI
home/linux/gui/base/          Linux GUI, DE-agnostic: GTK theme, Firefox (sandboxed), Chrome, fcitx5, gaming (opt-in)
home/linux/gui/plasma.nix     Plasma / KDE user apps
home/hosts/<name>.nix         per-host home module (picks one entry)
hardening/                    opt-in sandboxing: nixpaks/, bwraps/, profiles/
```

## Hosts

| Host       | Role                     | Home entry           | Desktop |
|------------|--------------------------|----------------------|---------|
| `faex1`    | physical desktop         | `linux/gui.nix`      | KDE Plasma 6 |
| `pve-lab1` | Proxmox VE sandbox VM    | `linux/gui.nix`      | KDE Plasma 6 |

## Desktop

KDE Plasma 6 is wired via the options pattern:

- System-level: `modules/nixos/desktop/plasma.nix` — SDDM, Plasma service, pipewire, graphics, printing, system fonts. Toggled by `modules.desktop.plasma.enable = true;` in the host.
- User-level: `home/linux/gui/plasma.nix` — KDE apps (kate, ark, gwenview, okular, spectacle, ...) installed per-user.
- Theme: `home/linux/gui/gtk.nix` — GTK cursor/font so GTK apps blend with Plasma.

Adding another DE (Hyprland, GNOME, ...): drop a new file in each of the two places, host enables via `modules.desktop.<name>.enable = true;`.

> NixOS tracks one Plasma release per nixpkgs channel. Use `nix flake update nixpkgs` to pull the latest (currently Plasma 6.6 on `nixos-unstable`).

## Home entry points (three tiers)

```
core.nix    daily baseline (any host): git, shell, tmux, btop, direnv, ...
tui.nix     core + base/tui: dev workstation extras (reserved — empty for now)
gui.nix     tui + linux/gui: KDE apps, GTK theme
```

Each host's `home/hosts/<name>.nix` picks **one** entry — no `default.nix`
in `home/linux/`, you must be explicit.

## Sandboxing

Three opt-in layers — see [hardening/README.md](./hardening/README.md):

- `hardening/nixpaks/` — per-app sandbox via [nixpak](https://github.com/nixpak/nixpak), exposed at `pkgs.nixpaks.<app>`
- `hardening/bwraps/` — per-app raw bubblewrap wrapper, exposed at `pkgs.bwraps.<app>`
- `hardening/profiles/` — NixOS hardened profile (system-wide, aggressive)

The overlay layers are wired into example hosts by default but have
**zero effect** until you add an app and reference it.

## First deploy

1. Generate hardware config on the target machine:
   `sudo nixos-generate-config --dir ./hw-dump` → copy `hardware-configuration.nix`
   into `hosts/<host>/` (replacing the placeholder).
2. Fill `vars/default.nix` — `username`, `useremail`, SSH keys,
   `initialHashedPassword` (generate via `mkpasswd -m yescrypt --rounds=11`).
3. (Optional) rename a host: update its name in three places —
   `outputs/x86_64-linux/src/<name>.nix`, `hosts/<name>/`, `home/hosts/<name>.nix`.
4. Deploy: `just switch <host>` (or `sudo nixos-rebuild switch --flake .#<host>`).

## Add a new host

Drop a file into `outputs/x86_64-linux/src/<host>.nix`, create
`hosts/<host>/`, and a `home/hosts/<host>.nix`. haumea picks it up
automatically. Pick a home entry (`core` / `tui` / `gui`) and, if it's a
VM, import `modules/nixos/server/qemu-guest.nix`.

## Common commands

```bash
just              # list all recipes
just switch <h>   # build and switch host <h>
just build <h>    # build only, don't switch
just update       # update all flake inputs
just fmt          # format all nix files
just check        # run eval-tests + pre-commit hooks
```
