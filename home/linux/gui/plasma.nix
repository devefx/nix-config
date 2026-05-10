{ pkgs, ... }:
# User-level Plasma / KDE apps. The Plasma desktop itself (SDDM,
# compositor, pipewire, ...) is installed system-wide via
# `modules.desktop.plasma.enable` in modules/nixos/desktop/plasma.nix.
#
# This file only covers what the user actually launches — keep apps here
# rather than in `environment.systemPackages` so different users on the
# same host can pick their own toolset.
{
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
