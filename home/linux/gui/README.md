# home/linux/gui

**English** | [简体中文](./README.zh-CN.md)

Linux-specific GUI user configuration. Pulled in by `home/linux/gui.nix` via `scanPaths`.

## Structure

```
home/linux/gui/
├── default.nix         scanPaths — auto-imports siblings
├── base/               DE-agnostic (applies regardless of compositor)
│   ├── default.nix     scanPaths
│   ├── gtk.nix         GTK cursor + font (GTK apps in any DE)
│   ├── firefox.nix     Firefox (sandboxed — see hardening/nixpaks/firefox.nix)
│   ├── chrome.nix      Google Chrome (unfree; has its own built-in sandbox)
│   ├── fcitx5.nix      Chinese input method (Pinyin / Shuangpin / Wubi)
│   ├── gaming.nix      Lutris + Proton-GE + Wine (needs modules.desktop.gaming)
│   ├── cc-switch.nix   CC Switch — AI provider config manager
│   ├── feishin.nix     Feishin — self-hosted music player (Jellyfin)
│   └── ...             one opt-in module per app, gated by modules.<app>.enable
├── plasma.nix          Plasma / desktop user apps (kate, ark, qimgv, ...)
└── niri/               Niri keybinds, window rules, Noctalia Shell
```

## DE-agnostic (`base/`) vs DE-specific (siblings)

| Where it goes             | Why                                                                               |
| ------------------------- | --------------------------------------------------------------------------------- |
| `base/gtk.nix`            | GTK theme applies to Firefox / VS Code regardless of which DE or compositor is on |
| `base/firefox.nix`        | Browser runs on any Linux DE, independent of compositor choice                    |
| `plasma.nix`              | Plasma / KDE apps only make sense when Plasma is enabled                          |
| `niri/`                   | Niri keybinds, window rules and Noctalia config only make sense in a Niri session |
| Future `hyprland/` subdir | Hyprland keybinds, layout — only meaningful when Hyprland is the session          |

Rule: **if it doesn't depend on a specific DE/WM, put it under `base/`**. If it only makes sense
with a particular compositor, put it in that compositor's subdir (or a flat `<de>.nix`).

## What belongs anywhere in here

Linux-specific user-level GUI configuration that doesn't fit in cross-platform `home/base/gui/`:

- Desktop environment apps (KDE, GNOME, Hyprland tooling)
- Display-server-specific config (Wayland compositor keybinds, X11 xresources)
- Linux input methods (fcitx5, ibus)
- GTK theming (GTK is primarily Linux)

## What does NOT belong here

| Should live where        | Examples                                                                               |
| ------------------------ | -------------------------------------------------------------------------------------- |
| `home/base/gui/`         | kitty, VS Code, Obsidian — apps with good home-manager support on both Linux and macOS |
| `modules/nixos/desktop/` | KDE's system service, Plasma Login Manager, pipewire — anything requiring root         |

## Adding a desktop environment's user bits

1. If the config is DE-agnostic (theme, input method, universal helper) → drop into
   `base/<name>.nix`.
2. If the config is specific to one DE/compositor → drop `<de>.nix` next to `plasma.nix`, or make a
   `<de>/` subdir for larger configs.
3. The matching system module goes to `modules/nixos/desktop/<de>.nix`.
