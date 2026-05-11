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
  home.packages = with pkgs.kdePackages; [
    kate              # editor
    ark               # archive manager
    partitionmanager  # disks
    filelight         # disk usage viewer
    kcalc             # calculator
    gwenview          # image viewer
    okular            # PDF / document viewer
    spectacle         # screenshot tool
  ];
}
