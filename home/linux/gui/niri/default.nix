# Niri Wayland compositor home-manager configuration
{
  pkgs,
  lib,
  config,
  ...
}: let
  confPath = ./conf;
in {
  home.packages = with pkgs; [
    xwayland-satellite # XWayland support for Niri
    wl-clipboard # Wayland clipboard utilities
    swaynotificationcenter # notification daemon
    fuzzel # application launcher
    swaylock-effects # screen locker
    grim # screenshot tool
    slurp # region selector
    brightnessctl # brightness control
    playerctl # media player control
    pamixer # PulseAudio mixer CLI
    noctalia-shell # desktop shell / panel
  ];

  # Symlink KDL config files
  xdg.configFile = {
    "niri/config.kdl".source = confPath + "/config.kdl";
    "niri/keybindings.kdl".source = confPath + "/keybindings.kdl";
    "niri/windowrules.kdl".source = confPath + "/windowrules.kdl";
  };

  # Polkit authentication agent
  systemd.user.services.niri-polkit = {
    Install.WantedBy = ["niri.service"];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # Wayland session script for greetd
  home.file.".wayland-session" = {
    source = pkgs.writeScript "init-session" ''
      systemctl --user is-active niri.service && systemctl --user stop niri.service
      /run/current-system/sw/bin/niri-session
    '';
    executable = true;
  };
}
