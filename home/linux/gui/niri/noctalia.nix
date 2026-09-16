{
  config,
  lib,
  pkgs,
  wallpapers,
  ...
}:
let
  # Retry DDC brightness reads after login; the monitor may not answer
  # ddcutil immediately after the output is reconnected.
  noctaliaShell = pkgs.noctalia-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../../../patches/noctalia-ddc-brightness-retry.patch
    ];
  });
in
lib.mkIf config.modules.desktop.niri.enable {
  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  };

  home.packages = [
    noctaliaShell
    pkgs.ddcutil # external monitor brightness through DDC/CI
    pkgs.kdePackages.breeze-icons
    pkgs.qt6Packages.qt6ct
    pkgs.papirus-icon-theme
    pkgs.app2unit
    pkgs.wlsunset
    pkgs.xrdb
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    pkgs.gpu-screen-recorder
  ];

  # ChatGPT runs through XWayland on this scaled output. Fcitx's XCB input
  # panel otherwise uses 96 DPI and renders smaller than native Wayland apps.
  xresources.properties."Xft.dpi" = 192;

  home.file."Pictures/Wallpapers".source = wallpapers;

  xdg.configFile = {
    # Keep ~/.config/noctalia as a real directory so Noctalia can generate
    # colors.json and other runtime state alongside the declarative files.
    "noctalia/settings.json".source = ./noctalia/config/settings.json;
    "noctalia/plugins.json".source = ./noctalia/config/plugins.json;
    "qt6ct/qt6ct.conf".source = ./noctalia/qt6ct.conf;
  };
}
