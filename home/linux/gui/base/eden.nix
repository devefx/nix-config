{
  lib,
  pkgs,
  config,
  ...
}:
# eden — Nintendo Switch 1 emulator derived from Yuzu and Sudachi,
# packaged natively in nixpkgs (v0.2.1 at the pinned nixpkgs rev).
#
# Gated behind `modules.eden.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.eden;
in
{
  options.modules.eden = {
    enable = mkEnableOption "eden Switch emulator";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.eden ];
  };
}
