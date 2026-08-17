{
  lib,
  pkgs,
  config,
  ...
}:
# Tsukimi — third-party Jellyfin client for Linux (GTK4 + mpv),
# packaged natively in nixpkgs (v26.7.1 at the pinned nixpkgs rev).
#
# Gated behind `modules.tsukimi.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.tsukimi;
in
{
  options.modules.tsukimi = {
    enable = mkEnableOption "Tsukimi Jellyfin client";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.tsukimi ];
  };
}
