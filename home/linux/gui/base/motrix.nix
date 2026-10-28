{
  lib,
  pkgs,
  config,
  ...
}:
# Motrix — full-featured download manager (HTTP / FTP / BitTorrent / magnet)
# built on aria2. Packaged from the upstream AppImage in `pkgs/motrix`
# because nixpkgs still ships the pre-rewrite 1.8.19 release.
#
# Gated behind `modules.motrix.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.motrix;
in
{
  options.modules.motrix = {
    enable = mkEnableOption "Motrix download manager";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../../pkgs/motrix { })
    ];
  };
}
