{
  lib,
  pkgs,
  osConfig,
  ...
}:
# Lutris GUI launcher + Proton-GE + Wine + perf overlays.
#
# Gated by the system-level `modules.desktop.gaming.enable` option so the
# Wine/Proton closure (~2GB) only lands on hosts that opted in. Enable at
# the host level: `modules.desktop.gaming.enable = true;` — that turns on
# the matching system module (Steam, GameMode, 32-bit GPU drivers) AND
# unlocks this home-manager module via the mkIf below.
let
  steamLauncher = pkgs.writeShellApplication {
    name = "steam";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [[ -n "''${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
        window_id="$(
          niri msg --json windows 2>/dev/null |
            jq -r '[.[] | select((.app_id // "") == "steam" or (.app_id // "") == "steam_app_default")] | first | .id // empty' 2>/dev/null
        )" || true

        if [[ -n "$window_id" ]]; then
          niri msg action focus-workspace "4entertainment" >/dev/null 2>&1 || true
          niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
          exit 0
        fi

        # Steam is assigned to workspace 4 below. Switch there before launch
        # so opening it from another workspace gives visible feedback.
        niri msg action focus-workspace "4entertainment" >/dev/null 2>&1 || true
      fi

      exec ${lib.getExe osConfig.programs.steam.package} "$@"
    '';
  };

  lutrisLauncher = pkgs.writeShellApplication {
    name = "lutris-launcher";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [[ -n "''${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
        window_id="$(
          niri msg --json windows 2>/dev/null |
            jq -r '[.[] | select((.app_id // "") == "net.lutris.Lutris")] | first | .id // empty' 2>/dev/null
        )" || true

        if [[ -n "$window_id" ]]; then
          niri msg action focus-workspace "4entertainment" >/dev/null 2>&1 || true
          niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
          exit 0
        fi

        # Lutris is assigned to workspace 4 below. Switch there before launch
        # so opening it from another workspace gives visible feedback.
        niri msg action focus-workspace "4entertainment" >/dev/null 2>&1 || true
      fi

      exec lutris "$@"
    '';
  };
in
lib.mkIf (osConfig.modules.desktop.gaming.enable or false) {
  programs.lutris = {
    enable = true;

    # Reuse the system-level Steam instead of pulling a second closure.
    steamPackage = osConfig.programs.steam.package;

    # Community Proton fork with more per-game fixes than vanilla Proton.
    protonPackages = [ pkgs.proton-ge-bin ];

    # WoW64 wine — 64-bit build that also runs 32-bit titles.
    winePackages = [ pkgs.wineWow64Packages.full ];

    extraPackages = with pkgs; [
      winetricks # install Windows DLLs / redistributables per prefix
      mangohud # FPS / CPU / GPU overlay (add `mangohud` to a game's command prefix)
      gamemode # userland CLI — actual effect requires programs.gamemode.enable at system level
      gamescope # resolution scaling / frame limiter
    ];
  };

  home.packages = [ steamLauncher ];

  # Override the upstream entry so Niri focuses an existing Lutris window or
  # switches to workspace 4 before starting a new one.
  xdg.desktopEntries."net.lutris.Lutris" = {
    name = "Lutris";
    genericName = "Video Game Preservation Platform";
    comment = "Video Game Preservation Platform";
    exec = "${lib.getExe lutrisLauncher} %U";
    icon = "net.lutris.Lutris";
    categories = [
      "Game"
      "PackageManager"
    ];
    mimeType = [
      "x-scheme-handler/lutris"
      "application/x-lutris"
    ];
    startupNotify = true;
    settings.StartupWMClass = "net.lutris.Lutris";
  };
}
