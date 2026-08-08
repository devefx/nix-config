{
  lib,
  pkgs,
  config,
  ...
}:
# Feishin — self-hosted music player for Jellyfin (Electron + mpv),
# packaged natively in nixpkgs (v1.15.1 at the pinned nixpkgs rev).
#
# Gated behind `modules.feishin.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.feishin;
in
{
  options.modules.feishin = {
    enable = mkEnableOption "Feishin music player (Jellyfin)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.feishin ];
  };
}
