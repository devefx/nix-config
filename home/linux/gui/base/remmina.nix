{
  lib,
  pkgs,
  config,
  ...
}:
# Remmina — GTK remote desktop client with an address book for managing
# many hosts (RDP / VNC / SSH), packaged natively in nixpkgs (v1.4.43 at
# the pinned nixpkgs rev).
#
# Gated behind `modules.remmina.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.remmina;
in
{
  options.modules.remmina = {
    enable = mkEnableOption "Remmina remote desktop client";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.remmina ];
  };
}
