{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed Spotify — nixpak-wrapped (see hardening/nixpaks/spotify.nix),
# exposed as `pkgs.nixpaks.spotify`. Config / cache / data live in the nixpak
# private data dir (~/.var/app/com.spotify.Client) and survive rebuilds.
#
# The launcher focuses the window after startup: windowrules.kdl sends Spotify
# to 4entertainment, and niri does not switch to a non-active workspace when a
# window maps there, so launching would otherwise look like a no-op.
#
# Gated behind `modules.spotify.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;
  cfg = config.modules.spotify;

  base = pkgs.nixpaks.spotify;

  launcher = pkgs.writeShellApplication {
    name = "spotify";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.niri
    ];
    text = ''
      if [[ -z "''${NIRI_SOCKET:-}" ]]; then
        exec ${base}/bin/spotify "$@"
      fi

      ${base}/bin/spotify "$@" &
      child=$!

      for _ in $(seq 1 150); do
        id=$(
          niri msg --json windows 2>/dev/null |
            jq -r '.[] | select(.app_id | test("(?i)^spotify$")) | .id' 2>/dev/null |
            head -n 1
        ) || true
        if [[ -n "''${id:-}" ]]; then
          niri msg action focus-window --id "$id" >/dev/null 2>&1 && break
        fi
        sleep 0.1
      done

      wait "$child"
    '';
  };

  # Keep the nixpak desktop entry / icons that home-manager collects; only
  # bin/spotify is replaced by the focus launcher.
  spotify = pkgs.runCommandLocal "spotify" { } ''
    mkdir -p "$out"
    # -L: the nixpak buildEnv exposes bin/ and share/ as symlinks into its
    # parts, so dereference them instead of copying the links.
    cp -rL ${base}/. "$out/"
    chmod -R u+w "$out"
    rm -f "$out/bin/spotify"
    cp ${launcher}/bin/spotify "$out/bin/spotify"
    # The nixpak desktop entry execs the sandbox wrapper directly; point it at
    # the focus launcher instead.
    sed -i "s|^Exec=.*|Exec=$out/bin/spotify %U|" \
      "$out/share/applications/com.spotify.Client.desktop"
  '';
in
{
  options.modules.spotify = {
    enable = mkEnableOption "sandboxed Spotify (nixpak)";
  };

  config = mkIf cfg.enable {
    home.packages = [ spotify ];
  };
}
