{
  lib,
  pkgs,
  config,
  ...
}:
# 红果短剧 desktop client. Upstream only publishes a Linux AppImage that
# expects the host to provide WebKitGTK 4.1 + GStreamer, so it is packaged
# locally in `pkgs/hongguo-tv` instead of being run through an FHS wrapper.
#
# Gated behind `modules.hongguoTv.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.hongguoTv;
in
{
  options.modules.hongguoTv = {
    enable = mkEnableOption "红果短剧 desktop client (Linux AppImage)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../../pkgs/hongguo-tv { })
    ];
  };
}
