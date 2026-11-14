{
  lib,
  pkgs,
  config,
  ...
}:
# 短剧盒 (ShortDramaBox) desktop client — replaces the unmaintained
# `hongguo-tv` AppImage. Upstream only publishes an AppImage that expects the
# host to provide WebKitGTK 4.1 + GStreamer, so it is packaged locally in
# `pkgs/hongguo-shortdramabox` instead of being run through an FHS wrapper.
#
# Gated behind `modules.shortDramaBox.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.shortDramaBox;
in
{
  options.modules.shortDramaBox = {
    enable = mkEnableOption "短剧盒 desktop client (Linux AppImage)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../../pkgs/hongguo-shortdramabox { })
    ];
  };
}
