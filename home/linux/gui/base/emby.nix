{
  lib,
  pkgs,
  config,
  ...
}:
# Official Emby Linux desktop client. Currently distributed as a beta DEB by
# Emby, so it is packaged locally from the official package repository.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.emby;
in
{
  options.modules.emby = {
    enable = mkEnableOption "official Emby desktop client";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../../pkgs/emby-client { })
    ];
  };
}
