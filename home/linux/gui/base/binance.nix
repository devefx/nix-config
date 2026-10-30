{
  lib,
  pkgs,
  config,
  ...
}:
# Binance — desktop client for the crypto exchange (Electron). nixpkgs has no
# package and upstream ships only a rolling `.deb`, so it is repackaged from
# that archive in `pkgs/binance` (see the notes there about the hash drifting
# whenever Binance publishes a new build).
#
# Gated behind `modules.binance.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.binance;
in
{
  options.modules.binance = {
    enable = mkEnableOption "Binance desktop client";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../../pkgs/binance { })
    ];
  };
}
