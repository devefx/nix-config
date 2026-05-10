# Hardening

**English** | [简体中文](./README.zh-CN.md)

Three layers of **opt-in** security hardening. Nothing applies until you
wire it into a host module.

## Layers

### 1. System-level (`profiles/`)
Imports NixOS's built-in `profiles/hardened.nix` + a couple of extras
(disabled coredump, etc.).

> **Caution**: the hardened profile is aggressive — may break gaming,
> virtualisation, some proprietary drivers. Enable only if you know
> the trade-offs.

### 2. Per-app sandbox via Nixpak (`nixpaks/`)
Declarative bubblewrap-based sandboxing via
[nixpak](https://github.com/nixpak/nixpak). Exposes wrapped apps at
`pkgs.nixpaks.<name>`.

**Reusable sub-modules** live in `nixpaks/modules/` — every sandboxed app
imports from here so you don't re-implement dbus policy / GPU / fonts per app:

| Module | Purpose |
|--------|---------|
| `common.nix` | dbus policies, XDG portal access, MPRIS, mesa shader cache, fontconfig — needed by every GUI app |
| `gui-base.nix` | GPU, locale, GTK, cursor/icon themes, Wayland socket, XDG_RUNTIME_DIR |
| `network.nix` | `/etc/resolv.conf` bind + SSL certs + enable network |

**Add an app**:
1. Create `nixpaks/<app>.nix` that imports whichever modules it needs:
   ```nix
   imports = [ ./modules/gui-base.nix ./modules/common.nix ./modules/network.nix ];
   ```
2. Register it in `nixpaks/default.nix`'s overlay.
3. Reference as `pkgs.nixpaks.<app>`.

`hardening/nixpaks/firefox.nix` is the canonical worked example here —
wraps Firefox with GPU / wayland / pipewire sockets and scoped
read-write access to `~/.mozilla` + XDG user dirs only. Used by
`home/linux/gui/base/firefox.nix`.

### 3. Per-app sandbox via raw Bubblewrap (`bwraps/`)
Direct `extraBwrapArgs` wrapping — for AppImages or cases where nixpak's
DSL gets in the way. Exposes wrapped apps at `pkgs.bwraps.<name>`.

## How to enable in a host

Edit `outputs/x86_64-linux/src/<host>.nix`:

```nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "hosts/${name}"
  # overlays (safe — only register pkgs.nixpaks / pkgs.bwraps namespaces,
  # zero effect until you actually use one)
  "hardening/nixpaks"
  "hardening/bwraps"
  # full system hardening (optional — may break things, read the profile first)
  # "hardening/profiles"
];
```

Then use the sandboxed app like any other package:

```nix
environment.systemPackages = [ pkgs.nixpaks.firefox ];
# or in home-manager:
home.packages = [ pkgs.bwraps.wechat ];
```

## Why this design

- **Overlays, not mass imports** — the sandbox layer adds package namespaces
  without side-effects. Opt-in per app means an unused sandbox costs zero.
- **Three mechanisms, pick per app** — nixpak for well-behaved apps,
  raw bwrap for AppImages, hardened profile for machines you trust to be
  locked down.

## References

- [nixpak](https://github.com/nixpak/nixpak)
- [bubblewrap](https://github.com/containers/bubblewrap)
- [NixOS hardened profile](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/profiles/hardened.nix)
- Working examples: `ryan4yin-nix-config/hardening/`
