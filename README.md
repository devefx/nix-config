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
home/base/tui/                dev workstation extras (Rust toolchain opt-in; add pgcli / k9s / tokei / ... here)
home/base/gui/                cross-platform GUI: kitty, media (ffmpeg/imagemagick/...), dev-tools (network), ai-agents (opt-in)
home/linux/core.nix           Linux entry: CLI-only
home/linux/tui.nix            Linux entry: core + TUI tools
home/linux/gui.nix            Linux entry: core + TUI + GUI
home/linux/gui/base/          Linux GUI, DE-agnostic: GTK theme, Firefox (sandboxed), Chrome, fcitx5, gaming (opt-in)
home/linux/gui/plasma.nix     Plasma / KDE user apps
home/linux/gui/niri/          Niri keybinds, window rules, Noctalia Shell
home/hosts/<name>.nix         per-host home module (picks one entry)
hardening/                    opt-in sandboxing: nixpaks/, bwraps/, profiles/
```

## Hosts

| Host         | Role             | Home entry      | Desktop         |
| ------------ | ---------------- | --------------- | --------------- |
| `faex1`      | physical desktop | `linux/gui.nix` | KDE Plasma 6    |
| `faex1-niri` | same machine     | `linux/gui.nix` | Niri + Noctalia |

## Desktop

KDE Plasma 6 is wired via the options pattern:

- System-level: `modules/nixos/desktop/plasma.nix` — Plasma Login Manager, Plasma service, pipewire,
  graphics, printing, system fonts. Toggled by `modules.desktop.plasma.enable = true;` in the host.
- User-level: `home/linux/gui/plasma.nix` — desktop apps (kate, ark, qimgv, okular, spectacle, ...)
  installed per-user.
- Theme: `home/linux/gui/base/gtk.nix` — GTK cursor/font so GTK apps blend with Plasma.

Adding another DE (Hyprland, GNOME, ...): drop a new file in each of the two places, host enables
via `modules.desktop.<name>.enable = true;`.

`faex1-niri` uses the same layering for Niri/Noctalia:

- System-level: `modules/nixos/desktop/niri.nix` — Niri, greetd, PipeWire, portals, XWayland
  satellite.
- User-level: `home/linux/gui/niri/` — KDL keybinds/window rules, Noctalia Shell, screenshot and
  clipboard tools.

Switch sessions with `sudo nixos-rebuild switch --flake .#faex1-niri`; use `.#faex1` to return to
Plasma.

> NixOS tracks one Plasma release per nixpkgs channel. Use `nix flake update nixpkgs` to pull the
> latest (currently Plasma 6.6 on `nixos-unstable`).

## Niri shortcuts

`Mod` is Super in a TTY session. Noctalia Shell defaults to Simplified Chinese (`zh-CN`). Press
`Mod+Shift+/` for niri's built-in hotkey overlay; the full configuration lives in
[`keybindings.kdl`](./home/linux/gui/niri/conf/keybindings.kdl).

### Launch and session

| Action                    | Shortcut                         |
| ------------------------- | -------------------------------- |
| Open terminal             | `Mod+Return`, `Mod+Shift+Return` |
| Open application launcher | `Mod+D`, `Mod+Space`, `Search`   |
| Lock screen               | `Ctrl+Alt+L`                     |
| Open session menu         | `Mod+E`                          |
| Show hotkey overlay       | `Mod+Shift+/`                    |
| Close focused window      | `Mod+Q`                          |
| Quit niri                 | `Ctrl+Alt+Delete`                |
| Power off monitors        | `Mod+Shift+P`                    |
| Toggle shortcut inhibitor | `Mod+Escape`                     |

### Navigation

| Action                           | Shortcut                           |
| -------------------------------- | ---------------------------------- |
| Focus column left/right          | `Mod+Left/H`, `Mod+Right/L`        |
| Focus window up/down in a column | `Mod+Up/K`, `Mod+Down/J`           |
| Focus first/last column          | `Mod+Home`, `Mod+End`              |
| Focus monitor left/right/up/down | `Mod+Shift+Arrow/HJKL`             |
| Focus workspace up/down          | `Mod+Page_Up/I`, `Mod+Page_Down/U` |
| Focus named workspace 1-5 or 0   | `Mod+1` through `Mod+5`, `Mod+0`   |

Workspace names are `1terminal`, `2browser`, `3chat`, `4entertainment`, `5utility`, and `0other`.

### Move and arrange

| Action                                  | Shortcut                                        |
| --------------------------------------- | ----------------------------------------------- |
| Move column left/right                  | `Mod+Ctrl+Left/H`, `Mod+Ctrl+Right/L`           |
| Move window up/down in a column         | `Mod+Ctrl+Up/K`, `Mod+Ctrl+Down/J`              |
| Move column to first/last position      | `Mod+Ctrl+Home`, `Mod+Ctrl+End`                 |
| Move column to another monitor          | `Mod+Shift+Ctrl+Arrow/HJKL`                     |
| Move column to workspace up/down        | `Mod+Ctrl+Page_Up/I`, `Mod+Ctrl+Page_Down/U`    |
| Move column to named workspace 1-5 or 0 | `Mod+Ctrl+1` through `Mod+Ctrl+5`, `Mod+Ctrl+0` |
| Move workspace up/down                  | `Mod+Shift+Page_Up/I`, `Mod+Shift+Page_Down/U`  |
| Consume or expel window left/right      | `Mod+[`, `Mod+]`                                |
| Consume window into column / expel it   | `Mod+,`, `Mod+.`                                |
| Cycle preset column width               | `Mod+R`                                         |
| Cycle preset window height / reset it   | `Mod+Shift+R`, `Mod+Ctrl+R`                     |
| Maximize column / fullscreen window     | `Mod+F`, `Mod+Shift+F`                          |
| Expand column / center visible columns  | `Mod+Ctrl+F`, `Mod+Ctrl+C`                      |
| Adjust column width                     | `Mod+-`, `Mod+=`                                |
| Adjust window height                    | `Mod+Shift+-`, `Mod+Shift+=`                    |
| Toggle floating window                  | `Mod+V`                                         |
| Toggle tabbed column display            | `Mod+W`                                         |

### Utilities and hardware keys

| Action                          | Shortcut                                      |
| ------------------------------- | --------------------------------------------- |
| Clipboard history               | `Mod+Shift+V`                                 |
| Calculator                      | `Mod+C`                                       |
| Control center                  | `Mod+S`                                       |
| Annotate screenshot with Satty  | `Print`                                       |
| Screenshot to clipboard         | `Mod+Ctrl+S`                                  |
| Full screen to clipboard        | `Mod+Ctrl+Print`                              |
| OCR selected screenshot         | `Mod+Shift+O`                                 |
| Screenshot screen / window      | `Ctrl+Print`, `Alt+Print`                     |
| Volume up/down/mute             | `Volume Up`, `Volume Down`, `Volume Mute`     |
| Microphone mute                 | `Microphone Mute`                             |
| Play/pause, stop, previous/next | `Media Play`, `Media Stop`, `Media Prev/Next` |
| Screen brightness up/down       | `Brightness Up`, `Brightness Down`            |
| Keyboard backlight up/down      | `Keyboard Brightness Up/Down`                 |

## Home entry points (three tiers)

```
core.nix    daily baseline (any host): git, shell, tmux, btop, direnv, ...
tui.nix     core + base/tui: dev workstation extras (Rust toolchain opt-in)
gui.nix     tui + linux/gui: KDE apps, GTK theme
```

Each host's `home/hosts/<name>.nix` picks **one** entry — no `default.nix` in `home/linux/`, you
must be explicit.

## Sandboxing

Three opt-in layers — see [hardening/README.md](./hardening/README.md):

- `hardening/nixpaks/` — per-app sandbox via [nixpak](https://github.com/nixpak/nixpak), exposed at
  `pkgs.nixpaks.<app>`
- `hardening/bwraps/` — per-app raw bubblewrap wrapper, exposed at `pkgs.bwraps.<app>`
- `hardening/profiles/` — NixOS hardened profile (system-wide, aggressive)

The overlay layers are wired into example hosts by default but have **zero effect** until you add an
app and reference it.

## First deploy

1. Generate hardware config on the target machine: `sudo nixos-generate-config --dir ./hw-dump` →
   copy `hardware-configuration.nix` into `hosts/<host>/` (replacing the placeholder).
2. Fill `vars/default.nix` — `username`, `useremail`, SSH keys, `initialHashedPassword` (generate
   via `mkpasswd -m yescrypt --rounds=11`).
3. (Optional) rename a host: update its name in three places —
   `outputs/x86_64-linux/src/<name>.nix`, `hosts/<name>/`, `home/hosts/<name>.nix`.
4. Deploy: `just switch <host>` (or `sudo nixos-rebuild switch --flake .#<host>`).

## Add a new host

Drop a file into `outputs/x86_64-linux/src/<host>.nix`, create `hosts/<host>/`, and a
`home/hosts/<host>.nix`. haumea picks it up automatically. Pick a home entry (`core` / `tui` /
`gui`) and, if it's a VM, import `modules/nixos/server/qemu-guest.nix`.

## Local inference (gufo)

[gufo](https://github.com/gufo-org/gufo) is an inference engine specialised for Strix Halo
(`gfx1151`). `modules/nixos/server/gufo.nix` exposes it as `modules.gufo.*` and runs it as a
systemd-managed OpenAI-compatible server. Prerequisites — both already met here: the user is in the
`render` / `video` groups, and `ttm.pages_limit` is raised so the iGPU can map tens of GiB of GTT
(`hosts/faex1/default.nix` sets it to 96 GiB).

Weights stay out of the store (Flash-Next Q4 is ~104 GiB) and the module never fetches or creates
them. `model` / `mmproj` / `mtpModel` are resolved under `modules.gufo.modelsDir`, which defaults to
`~/models` — so the indirection lives in a symlink you own, not in a Nix string:

```bash
ln -s /mnt/data/Shared/github/workspace/gguf-model-presets/models ~/models
```

Expected layout, plus the fetch recipe (two separate `hf` calls — mixing explicit filenames with
`--include` makes `hf` silently ignore the glob):

```bash
D=~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL
R=38bb39ee97821de2c9009abb7e93950eec396e66
hf download unsloth/Qwen3.8-Flash-Next-GGUF --revision "$R" \
  --include "UD-Q4_K_XL/*" --local-dir "$D"
hf download unsloth/Qwen3.8-Flash-Next-GGUF --revision "$R" --local-dir "$D" \
  MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf mmproj-BF16.gguf
```

```
~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL/
├── UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-0000{1..4}-of-00004.gguf
├── MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
└── mmproj-BF16.gguf
```

Then enable it in a host:

```nix
modules.gufo = {
  enable = true;
  port = 8080;
  # modelsDir = "/srv/llm/models";  # override if ~/models is not where you link
  context = 262144;  # native context; 90.1 GiB measured on a 96 GiB GTT box
  sessions = 1;      # each extra session costs ~1.06 GiB; 2x131072 does not fit
};
```

Measured device usage on this 96 GiB GTT machine: 1x32768 = 84.25 GiB, 2x32768 = 85.31 GiB, 1x131072
= 86.76 GiB, 1x262144 = 90.12 GiB. Roughly 82.4 GiB is weights plus fixed overhead, 1.06 GiB per
session, and 26.8 MiB of KV per 1K tokens — so the model fits its native 256K context on a single
session without raising `ttm.pages_limit`.

`systemctl status gufo` for state, `curl localhost:8080/v1/models` to verify.

## Common commands

```bash
just              # list all recipes
just switch <h>   # build and switch host <h>
just build <h>    # build only, don't switch
just update       # update all flake inputs
just fmt          # format all nix files
just check        # run pre-commit hooks + evaluate every host
```
