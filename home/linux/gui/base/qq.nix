{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed QQ — nixpak-wrapped (see hardening/nixpaks/qq.nix), exposed
# as `pkgs.nixpaks.qq`.
#
# Gated behind `modules.qq.enable` — hosts that don't need QQ skip the
# Electron closure. Chat data lives in the nixpak private data dir
# (survives rebuilds, isolated from the rest of $HOME).
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.qq;
in
{
  options.modules.qq = {
    enable = mkEnableOption "sandboxed QQ (nixpak)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nixpaks.qq ];

    # QQ creates its own autostart entry with an absolute store path, which
    # becomes stale after rebuilds and bypasses the XAUTHORITY fallback.
    xdg.configFile."autostart/com.qq.QQ.desktop" = {
      source = "${pkgs.nixpaks.qq}/share/applications/com.qq.QQ.desktop";
      force = true;
    };
  };
}
