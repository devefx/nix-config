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
lib.mkIf (osConfig.modules.desktop.gaming.enable or false) {
  programs.lutris = {
    enable = true;

    # Reuse the system-level Steam instead of pulling a second closure.
    steamPackage = osConfig.programs.steam.package;

    # Community Proton fork with more per-game fixes than vanilla Proton.
    protonPackages = [ pkgs.proton-ge-bin ];

    # WoW64 wine — 64-bit build that also runs 32-bit titles.
    winePackages = [ pkgs.wineWowPackages.full ];

    extraPackages = with pkgs; [
      winetricks # install Windows DLLs / redistributables per prefix
      mangohud # FPS / CPU / GPU overlay (add `mangohud` to a game's command prefix)
      gamemode # userland CLI — actual effect requires programs.gamemode.enable at system level
      gamescope # resolution scaling / frame limiter
    ];
  };
}
