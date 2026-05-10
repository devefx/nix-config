{
  lib,
  config,
  ...
}:
# Gaming infrastructure — Steam, GameMode, 32-bit GPU drivers.
#
# Pairs with home/linux/gui/base/gaming.nix (Lutris + Wine + Proton).
# Both layers key off the same `modules.desktop.gaming.enable` switch so
# non-gaming hosts don't pull in the ~2GB Wine/Proton closure.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.gaming;
in
{
  options.modules.desktop.gaming = {
    enable = mkEnableOption "Steam / Lutris / gaming infrastructure";
  };

  config = mkIf cfg.enable {
    # Many Windows games (even 64-bit ones) ship 32-bit launchers or DLLs.
    hardware.graphics.enable32Bit = true;

    # Userland daemon that bumps CPU governor / I/O / niceness while a
    # game runs. Games with built-in integration activate it automatically;
    # for others, wrap with `gamemoderun <cmd>`.
    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      # Upscaling / frame-limit / handheld-style composition.
      gamescopeSession.enable = true;
      # Winetricks wrapper for Proton prefixes.
      protontricks.enable = true;
    };
  };
}
