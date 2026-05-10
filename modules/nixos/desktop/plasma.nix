{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.plasma;
in
{
  options.modules.desktop.plasma = {
    enable = mkEnableOption "KDE Plasma 6 desktop environment";
  };

  config = mkIf cfg.enable {
    # XWayland needs xserver even though Plasma 6 runs on pure Wayland.
    services.xserver.enable = true;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    services.desktopManager.plasma6.enable = true;

    hardware.graphics.enable = true;

    environment.plasma6.excludePackages = with pkgs.kdePackages; [
      elisa
      khelpcenter
      konsole
    ];

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    services.printing.enable = true;
  };
}
