{
  config,
  lib,
  pkgs,
  noctaliaFlake,
  wallpapers,
  ...
}:
let
  # Noctalia v5 is a ground-up C++/Wayland rewrite: a different binary
  # (`noctalia`), a different IPC (`noctalia msg ...`) and a TOML config. It is
  # therefore a separate package, not an upgrade of `noctalia-shell` (v4, built
  # on Quickshell). The three v4 QML patches that used to live in patches/
  # (ddc-read-once, idle-monitor-wake, niri-output-dpms) are gone with it: v5
  # has no QML to patch and handles all three cases itself (DDC discovery
  # retries with per-monitor cooldown, a native screen-off idle action that
  # restores monitor power, and dpms-on/dpms-off IPC).
  #
  # The upstream flake is used instead of pkgs.noctalia because:
  #
  #   * nixpkgs unstable still carries 5.2.1, while this config uses keys that
  #     only exist from 5.3/5.4 (backdrop, card_borders, search_position,
  #     show_when_unavailable, ...). Unknown keys are only warnings in v5, so
  #     the difference would be silent missing features.
  #   * the input deliberately does NOT follow our nixpkgs. Upstream publishes
  #     prebuilt binaries on cachix built against their own nixpkgs pin; making
  #     it follow ours would change the derivation hash and force a local C++
  #     build. nixConfig in flake.nix adds their substituter.
  #
  # The package is used unmodified on purpose: any overrideAttrs would change
  # the hash and lose that cache. Its wrapper only puts `git` on PATH, so the
  # commands v5 shells out to (ddcutil for DDC/CI brightness, dconf/gsettings,
  # systemctl) are taken from the session PATH -- see home.packages below.
  #
  # Patching v5's workspace-pill easing to mimic v4's overshoot was tried and
  # dropped: v4's "bubble" is a separate effect (an expanding, fading ring drawn
  # by WorkspacePill.qml's `pillBurst`), not the width transition, so the easing
  # change reproduced nothing -- and it cost a ~17 min local C++ rebuild per
  # noctalia bump.
  noctalia = noctaliaFlake.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
lib.mkIf config.modules.desktop.niri.enable {
  # Read by modules that must talk to the running shell (ntfy-voice's
  # do-not-disturb probe). Unlike v4, v5's IPC socket is
  # `$XDG_RUNTIME_DIR/noctalia-<WAYLAND_DISPLAY>.sock`, so it is independent of
  # the store path and any `noctalia` binary on PATH can reach the instance --
  # but pointing at the same build keeps the CLI and the daemon in lockstep.
  modules.desktop.niri.noctalia = noctalia;

  home.packages = [
    noctalia
    # v5 runs `ddcutil` itself for DDC/CI brightness instead of linking a
    # library, and its wrapper does not add it: the binary has to be on the
    # session PATH, which the home-manager profile provides. This panel has no
    # backlight device, so DDC is the only way to dim it. Also useful by hand
    # (`ddcutil detect`) when a monitor's brightness control does not appear.
    pkgs.ddcutil
    # v5 resolves StatusNotifierItem glyphs through the icon theme itself, so
    # the tray still needs breeze-icons for the symbolic icons that only live
    # there (input-keyboard-symbolic, user-desktop, application-x-executable).
    # Papirus-Dark comes from home/linux/gui/base/gtk.nix.
    pkgs.kdePackages.breeze-icons
    pkgs.xrdb
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    # Not used by v5 itself: the screen recorder moved to the official
    # `noctalia/screen_recorder` plugin, which drives this binary. Installed so
    # enabling the plugin in Settings works without another rebuild.
    pkgs.gpu-screen-recorder
  ];

  # v4 needed `wlsunset` (night light was a spawned helper) and `app2unit`
  # (launcher entries were started through it). v5 does night light itself over
  # wlr-gamma-control and launches apps directly, so both packages are gone.

  # ChatGPT runs through XWayland on this scaled output. Fcitx's XCB input
  # panel otherwise uses 96 DPI and renders smaller than native Wayland apps.
  xresources.properties."Xft.dpi" = 192;

  home.file."Pictures/Wallpapers".source = wallpapers;

  xdg.configFile = {
    # v5 merges every *.toml in ~/.config/noctalia/ (alphabetically) and keeps
    # its own runtime state -- GUI overrides, palettes, plugin materialisations,
    # encrypted clipboard/notification history -- under
    # ~/.local/state/noctalia/, so the config directory only holds this file.
    "noctalia/config.toml".source = ./noctalia/config.toml;
    # Custom palettes selected by `[theme] custom_palette`. v5 reads these from
    # ~/.config/noctalia/palettes/<name>.json, so they have to live under the
    # config directory rather than in the store-only tree. Macchiato is the
    # active one (Catppuccin Macchiato + Latte); WhiteSur, Layan and Orchis are
    # the alternatives -- switching is one line in config.toml, and v5 only ships
    # Mocha built in.
    "noctalia/palettes/WhiteSur.json".source = ./noctalia/palettes/WhiteSur.json;
    "noctalia/palettes/Layan.json".source = ./noctalia/palettes/Layan.json;
    "noctalia/palettes/Orchis.json".source = ./noctalia/palettes/Orchis.json;
    "noctalia/palettes/Macchiato.json".source = ./noctalia/palettes/Macchiato.json;
  };

  # The previous bar may outlive a rebuild in two ways, and both leave the
  # session looking broken:
  #
  #   1. v4 (noctalia-shell/Quickshell) still running while v5 starts: two bars
  #      on top of each other, and every `noctalia msg` from a keybind fails
  #      because v4 never had that socket.
  #   2. A v5 binary from an older store path: the socket name does not include
  #      the store path, so the new CLI does talk to it, but the daemon is still
  #      the old build with the old config schema.
  #
  # Restart only when the store path actually changed. The state file is left
  # untouched whenever the restart cannot be performed, so a later activation
  # retries instead of recording a path that was never applied.
  home.activation.restartNoctaliaOnPathChange = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state_file="$HOME/.cache/niri-noctalia-path"
    shell_bin="${noctalia}/bin/noctalia"

    if [ "$(cat "$state_file" 2>/dev/null || true)" != "$shell_bin" ] && [ -z "''${DRY_RUN:-}" ]; then
      # pgrep is unavailable here: home-manager-yoke.service gets a minimal
      # coreutils/grep PATH with no procps, so scan /proc directly.
      bar_pids=""
      for proc in /proc/[0-9]*; do
        cmd="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
        case "$cmd" in
          # v4 shell left over from before the migration.
          *"quickshell"*"noctalia-shell"*) bar_pids="$bar_pids ''${proc#/proc/}" ;;
          # v5 daemon: the wrapper, the real .noctalia-wrapped binary, or a bare
          # /bin/noctalia at the end of the command line.
          *"/bin/noctalia "|*"/bin/noctalia"|*/.noctalia-wrapped*)
            bar_pids="$bar_pids ''${proc#/proc/}"
            ;;
        esac
      done

      if [ -z "$bar_pids" ]; then
        # No shell running: nothing to restart. niri's spawn-at-startup starts
        # the new one at next login.
        printf '%s' "$shell_bin" > "$state_file"
      else
        # NIRI_SOCKET is normally inherited from the systemd user manager,
        # which imports it at login; fall back to the runtime socket.
        if [ -z "''${NIRI_SOCKET:-}" ]; then
          for socket in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/niri.wayland-*.sock; do
            if [ -S "$socket" ]; then
              NIRI_SOCKET="$socket"
              export NIRI_SOCKET
              break
            fi
          done
        fi

        # Without a compositor socket the shell cannot be respawned, and
        # killing it would leave the session without a bar. Skip and retry.
        if [ -n "''${NIRI_SOCKET:-}" ]; then
          # Kill every matching process first, then wait for all of them: a
          # leftover bar from the other version must not survive the respawn.
          for pid in $bar_pids; do
            kill "$pid" 2>/dev/null || true
          done
          for pid in $bar_pids; do
            for _ in $(seq 1 50); do
              [ -e "/proc/$pid" ] || break
              sleep 0.1
            done
          done

          # niri is not on the activation PATH; the system profile path is
          # the same binary the running compositor uses.
          niri_bin="$(command -v niri || true)"
          [ -n "$niri_bin" ] || niri_bin=/run/current-system/sw/bin/niri
          "$niri_bin" msg action spawn -- "$shell_bin" || true

          printf '%s' "$shell_bin" > "$state_file"
        fi
      fi
    fi
  '';
}
