{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed AyuGram Desktop — Telegram fork from the ayugram-desktop
# flake input, wrapped via nixpak (see hardening/nixpaks/ayugram-desktop.nix).
# Gated behind `modules.ayugram.enable` so hosts that don't want it skip
# the Qt closure.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.ayugram;
in
{
  options.modules.ayugram = {
    enable = mkEnableOption "sandboxed AyuGram Desktop (Telegram fork, nixpak)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nixpaks.ayugram-desktop ];
  };
}
