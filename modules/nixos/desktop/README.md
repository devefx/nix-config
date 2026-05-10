# modules/nixos/desktop

**English** | [简体中文](./README.zh-CN.md)

Desktop environment system modules. Each DE is gated behind an option
so hosts opt in to exactly what they want.

## Contents

| File | Option | What it enables |
|------|--------|-----------------|
| `default.nix` | — | `scanPaths ./.`  — auto-imports everything here |
| `plasma.nix` | `modules.desktop.plasma.enable` | KDE Plasma 6 (SDDM, Plasma service, pipewire, printing, graphics, system fonts) |

## How a host uses it

Two things are needed. First, add the group to the host's nixos-modules:

```nix
# outputs/x86_64-linux/src/<host>.nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "modules/nixos/desktop"    # ← this
  "hosts/${name}"
];
```

Then enable a specific DE in the host's config:

```nix
# hosts/<host>/default.nix
modules.desktop.plasma.enable = true;
```

Without the second line, importing `modules/nixos/desktop` is a no-op —
you only pay for what you enable.

## System-level vs user-level

Files here set up the **system side** of a desktop:

- display manager (SDDM, GDM, greetd, ...)
- the compositor / session (Plasma, GNOME, Hyprland, ...) — as a NixOS service
- audio stack (pipewire), graphics, printing, system fonts

The **user side** (which apps the user actually launches, GTK/Qt theme
preferences, shell configs) lives in `home/linux/gui/`.

## Adding a desktop environment

1. Drop `<de>.nix` here using the options pattern:

   ```nix
   { lib, config, pkgs, ... }:
   with lib;
   let cfg = config.modules.desktop.<de>;
   in {
     options.modules.desktop.<de> = {
       enable = mkEnableOption "<de> desktop environment";
     };
     config = mkIf cfg.enable {
       # display manager, compositor service, audio, graphics, fonts
     };
   }
   ```

2. Add the matching user-level file at `home/linux/gui/<de>.nix`
   (apps, theme, shortcuts).

3. Hosts enable with `modules.desktop.<de>.enable = true;`. Adding a
   second DE doesn't require touching existing code.
