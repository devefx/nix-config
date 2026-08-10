{
  lib,
  pkgs,
  config,
  ...
}:
# Karere - native GTK4/WebKit WhatsApp Web client, packaged natively in
# nixpkgs (v3.1.1 at the pinned nixpkgs rev).
#
# Gated behind `modules.karere.enable` - enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.karere;
in
{
  options.modules.karere = {
    enable = mkEnableOption "Karere WhatsApp client (GTK4/WebKit)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.karere ];
  };
}
