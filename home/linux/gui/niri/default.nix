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
    swaynotificationcenter # notification daemon
    fuzzel # application launcher
    noctalia-shell # desktop shell / panel
  ];

  # Symlink KDL config files
  xdg.configFile = {
    "niri/config.kdl".source = confPath + "/config.kdl";
    "niri/keybindings.kdl".source = confPath + "/keybindings.kdl";
    "niri/windowrules.kdl".source = confPath + "/windowrules.kdl";
  };

  # Polkit authentication agent
  systemd.user.services.niri-flake-polkit = {
    Unit = {
      Description = "PolicyKit Authentication Agent provided by niri-flake";
      After = ["graphical-session.target"];
      Wants = ["graphical-session-pre.target"];
    };
    Install.WantedBy = ["niri.service"];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Wayland session script for greetd
  home.file.".wayland-session" = {
    source = pkgs.writeScript "init-session" ''
      # trying to stop a previous niri session
      systemctl --user is-active niri.service && systemctl --user stop niri.service
      # and then we start a new one
      /run/current-system/sw/bin/niri-session
    '';
    executable = true;
  };
}
