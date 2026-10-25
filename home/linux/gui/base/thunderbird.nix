{
  lib,
  pkgs,
  config,
  ...
}:
# Mozilla Thunderbird — mail client.
#
# Gated behind `modules.thunderbird.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.modules.thunderbird;
in
{
  options.modules.thunderbird = {
    enable = mkEnableOption "Thunderbird mail client";

    autostart = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Start Thunderbird automatically when the graphical session comes up.

        Uses the XDG autostart entry Thunderbird itself ships rather than a
        systemd unit: Thunderbird is a GUI-only application that expects a
        Wayland/X11 session, which is exactly what `autostart/` is for. The
        file is copied with `force` so that any entry Thunderbird writes for
        itself (it does, with an absolute store path that goes stale on the
        next rebuild) is replaced by this one.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.thunderbird ];

    xdg.configFile = mkIf cfg.autostart {
      "autostart/thunderbird.desktop" = {
        source = "${pkgs.thunderbird}/share/applications/thunderbird.desktop";
        force = true;
      };
    };
  };
}
