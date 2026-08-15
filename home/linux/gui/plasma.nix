{
  lib,
  pkgs,
  osConfig,
  ...
}:
# User-level Plasma / KDE apps. The Plasma desktop itself (SDDM,
# compositor, pipewire, ...) is installed system-wide via
# `modules.desktop.plasma.enable` in modules/nixos/desktop/plasma.nix.
#
# Gated on the same system option so headless / non-KDE hosts don't pull
# the KDE app closure into their home profile.
lib.mkIf (osConfig.modules.desktop.plasma.enable or false) {
  # Declarative Plasma settings. The panel below mirrors the current layout
  # but intentionally omits the "minimize all windows" applet.
  programs.plasma = {
    enable = true;

    workspace = {
      theme = "Ant-Dark";
      widgetStyle = "Darkly";
      colorScheme = "Darkly";
      windowDecorations = {
        library = "org.kde.darkly";
        theme = "Darkly";
      };
    };

    configFile = {
      kdeglobals = {
        General.ColorScheme = "Darkly";
      };
      darklyrc = {
        Style = {
          MenuOpacity = 100;
          DolphinSidebarOpacity = 70;
          DolphinViewOpacity = 70;
          MenuBarOpacity = 70;
          ToolBarOpacity = 70;
          TabBarOpacity = 70;
        };
      };
      kwinrc = {
        # KWin 6.7.4 saturation range is 100-500 (17 notches); notch 5 writes 200.
        "Effect-blur".Saturation = 200;
      };
      # window-rules is empty now, so write an explicit empty rules file to
      # overwrite the previously managed System Settings transparency rule.
      kwinrulesrc = {
        General = {
          count = 0;
          rules = "";
        };
      };
    };

    krunner = {
      position = "center";
    };

    kwin = {
      effects = {
        minimization = {
          animation = "magiclamp";
          duration = 200;
        };
        blur = {
          enable = true;
          strength = 8;
          noiseStrength = 0;
        };
      };
    };

    panels = [
      {
        location = "bottom";
        height = 46;
        floating = true;
        opacity = "translucent";
        widgets = [
          "org.kde.plasma.kickoff"
          {
            name = "org.kde.plasma.windowlist";
            config.General = {
              showIcon = true;
              showText = true;
            };
          }
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.icontasks"
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.marginsseparator"
          "org.kde.plasma.systemtray"
          "org.kde.plasma.digitalclock"
        ];
      }
    ];
  };

  home.packages =
    with pkgs.kdePackages;
    [
      kate # editor
      ark # archive manager
      partitionmanager # disks
      filelight # disk usage viewer
      kcalc # calculator
      gwenview # image viewer
      okular # PDF / document viewer
      spectacle # screenshot tool
    ]
    ++ [
      pkgs.haruna
      pkgs.nvtopPackages.amd # GPU monitoring for AMD
    ];
}
