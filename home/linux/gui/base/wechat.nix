{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed WeChat (Linux AppImage wrapped in bwrap). Package is defined
# in `hardening/bwraps/wechat.nix` and exposed as `pkgs.bwraps.wechat`.
#
# Gated behind `modules.wechat.enable` — hosts that don't need WeChat
# skip the ~300MB AppImage closure. Chat data lands in
# `~/Documents/WeChat_Data/` (the bwrap wrapper fakes HOME to that dir).
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.wechat;
in
{
  options.modules.wechat = {
    enable = mkEnableOption "sandboxed WeChat (Linux AppImage via bwrap)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.bwraps.wechat ];
  };
}
