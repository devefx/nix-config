# Wayland desktop environment variables and utilities
{pkgs, ...}: {
  home.sessionVariables = {
    "NIXOS_OZONE_WL" = "1"; # for ozone-based browser & electron apps
    "MOZ_ENABLE_WAYLAND" = "1";
    "MOZ_WEBRENDER" = "1";
    "ELECTRON_OZONE_PLATFORM_HINT" = "auto";
    "_JAVA_AWT_WM_NONREPARENTING" = "1";
    "QT_WAYLAND_DISABLE_WINDOWDECORATION" = "1";
    "QT_QPA_PLATFORM" = "wayland";
    "SDL_VIDEODRIVER" = "wayland";
    "GDK_BACKEND" = "wayland";
    "XDG_SESSION_TYPE" = "wayland";
  };

  home.packages = with pkgs; [
    wl-clipboard # copying and pasting
    brightnessctl
    alsa-utils # provides amixer/alsamixer/...
    networkmanagerapplet # nm-connection-editor
    grim # screenshot tool
    slurp # region selector
  ];

  # screen locker
  programs.swaylock.enable = true;
}
