{
  lib,
  pkgs,
  config,
  ...
}:
# Clash Verge Rev — Clash GUI (Tauri), packaged natively in nixpkgs
# (v2.5.2 at the pinned nixpkgs rev).
#
# For TUN mode / the privilege service, additionally enable the NixOS
# module `programs.clash-verge` (nixpkgs' nixos/modules/programs/clash-verge.nix)
# with its `serviceMode` / `tunMode` options — not required for the plain
# desktop app.
#
# Gated behind `modules.clashVerge.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.clashVerge;
in
{
  options.modules.clashVerge = {
    enable = mkEnableOption "Clash Verge Rev (Clash GUI)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.clash-verge-rev ];
  };
}
