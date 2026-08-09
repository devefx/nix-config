{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed iMe Messenger — Telegram API client with crypto wallet features.
# Package is defined in hardening/nixpaks/ime.nix and exposed as
# pkgs.nixpaks.ime-desktop.
#
# Gated behind `modules.ime.enable`; enable in home/hosts/<name>.nix.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.ime;
in
{
  options.modules.ime = {
    enable = mkEnableOption "sandboxed iMe Messenger (nixpak)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nixpaks.ime-desktop ];
  };
}
