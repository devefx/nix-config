{
  lib,
  pkgs,
  config,
  ...
}:
# eden — Nintendo Switch 1 emulator derived from Yuzu and Sudachi,
# packaged natively in nixpkgs (v0.2.1 at the pinned nixpkgs rev).
#
# Gated behind `modules.eden.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.eden;
in
{
  options.modules.eden = {
    enable = mkEnableOption "eden Switch emulator";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.eden ];

    # Run eden on the native Wayland QPA.
    # eden links qtwayland but takes its QPA platform from the environment, and
    # nothing under niri sets QT_QPA_PLATFORM, so Qt fell back to xcb through
    # xwayland-satellite (measured: platforms/libqxcb.so loaded, no
    # wayland-decoration-client plugin at all). Only the Wayland QPA gives the
    # window a title bar drawn by the decoration plugin selected in
    # niri/conf/config.kdl.
    #
    # This overrides the .desktop *entry*, not the package: an overrideAttrs on
    # pkgs.eden would change its derivation and re-resolve qt6.qtwebengine
    # (Chromium, hours to build). Overriding the entry leaves the closure alone.
    #
    # The attribute name *is* the filename, and it has to be the ID upstream
    # ships (`dev.eden_emu.eden`): home-manager installs desktop entries with
    # lib.hiPrio, so matching the ID is what makes the profile's buildEnv pick
    # this copy over the package's. A key of `eden` only added a second,
    # losing entry.
    #
    # MimeType is repeated because an xdg.desktopEntries override replaces the
    # whole entry instead of merging into the package's; `%f` is kept so opening
    # a ROM from the file manager still passes the path through.
    xdg.desktopEntries."dev.eden_emu.eden" = {
      name = "Eden";
      genericName = "Switch Emulator";
      comment = "Multiplatform FOSS Switch 1 emulator written in C++, derived from Yuzu and Sudachi";
      icon = "dev.eden_emu.eden";
      # Two environment variables, each for a measured reason.
      #
      # QT_QPA_PLATFORM=wayland -- see above (verified via /proc/<pid>/maps:
      # libqwayland.so instead of libqxcb.so).
      #
      # QT_PLUGIN_PATH -- eden's own wrapper replaces this with its Qt module
      # plugin dirs (qtwayland, qtsvg, qtdeclarative, ...), none of which
      # contains qt6ct or Kvantum, so the profile dir is prepended to keep the
      # platform theme and the widget style discoverable. The path comes from
      # config.home.profileDirectory so the username is not hardcoded, and
      # `env VAR=... prog` (rather than a shell) keeps the existing wrapper
      # semantics.
      exec = "env QT_QPA_PLATFORM=wayland QT_PLUGIN_PATH=${config.home.profileDirectory}/lib/qt-6/plugins eden %f";
      categories = [
        "Game"
        "Emulator"
        "Qt"
      ];
      mimeType = [
        "application/x-nx-nro"
        "application/x-nx-nso"
        "application/x-nx-nsp"
        "application/x-nx-xci"
      ];
      # Not first-class options in this home-manager: they go through
      # `settings`, which is written into [Desktop Entry] verbatim.
      settings = {
        Keywords = "Nintendo;Switch;";
        StartupWMClass = "eden";
      };
    };
  };
}
