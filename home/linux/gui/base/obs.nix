{
  lib,
  pkgs,
  config,
  ...
}:
# OBS Studio — screen recording and live streaming.
#
# Gated behind `modules.obs.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.obs;
in
{
  options.modules.obs = {
    enable = mkEnableOption "OBS Studio";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.obs-studio ];
  };
}
