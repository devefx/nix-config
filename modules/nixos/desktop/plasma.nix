{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.plasma;
  antDarkTheme = pkgs.callPackage ../../../pkgs/ant-dark { };
in
{
  options.modules.desktop.plasma = {
    enable = mkEnableOption "KDE Plasma 6 desktop environment";
  };

  config = mkIf cfg.enable {
    # XWayland needs xserver even though Plasma 6 runs on pure Wayland.
    services.xserver.enable = true;

    # KDE's native login manager — replaces SDDM as the default login screen.
    services.displayManager.plasma-login-manager.enable = true;

    services.desktopManager.plasma6.enable = true;

    hardware.graphics.enable = true;

    environment.systemPackages = [
      pkgs.darkly
      antDarkTheme
    ];

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

    # The login manager and Plasma prefer the AccountsService icon over
    # ~/.face.icon. Refresh it when the system switches, not on every boot.
    system.activationScripts.userAvatar.text = ''
      install -D -m 0644 ${../../../assets/avatars/yoke.jpg} /var/lib/AccountsService/icons/yoke
    '';
  };
}
