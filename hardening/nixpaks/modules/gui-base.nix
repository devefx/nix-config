# https://github.com/nixpak/pkgs/blob/master/pkgs/modules/gui-base.nix
{
  config,
  lib,
  pkgs,
  sloth,
  ...
}:
let
  envSuffix = envKey: suffix: sloth.concat' (sloth.env envKey) suffix;
  cursorTheme = pkgs.bibata-cursors;
  iconTheme = pkgs.papirus-icon-theme;
in
{
  config = {
    dbus.policies = {
      "${config.flatpak.appId}" = "own";
    };
    gpu = {
      enable = lib.mkDefault true;
      provider = "nixos";
      bundlePackage = pkgs.mesa.drivers;
    };
    fonts.enable = false;
    locale.enable = true;
    bubblewrap = {
      network = lib.mkDefault false;
      bind.rw = [
        [
          (envSuffix "HOME" "/.var/app/${config.flatpak.appId}/cache")
          sloth.xdgCacheHome
        ]
        (sloth.concat' sloth.xdgCacheHome "/fontconfig")
        (sloth.concat' sloth.xdgCacheHome "/mesa_shader_cache")

        (sloth.concat [
          (sloth.env "XDG_RUNTIME_DIR")
          "/"
          (sloth.envOr "WAYLAND_DISPLAY" "no")
        ])

        (envSuffix "XDG_RUNTIME_DIR" "/at-spi/bus")
        (envSuffix "XDG_RUNTIME_DIR" "/gvfsd")
        (envSuffix "XDG_RUNTIME_DIR" "/pulse")

        "/run/dbus"
      ];
      bind.ro = [
        (envSuffix "XDG_RUNTIME_DIR" "/doc")
        (sloth.concat' sloth.xdgConfigHome "/gtk-2.0")
        (sloth.concat' sloth.xdgConfigHome "/gtk-3.0")
        (sloth.concat' sloth.xdgConfigHome "/gtk-4.0")
        (sloth.concat' sloth.xdgConfigHome "/fontconfig")

        "/etc/fonts"
        "/etc/localtime"
        "/etc/zoneinfo"

        "/etc/egl"
        "/etc/static/egl"
      ];
      bind.dev = [
        "/dev/shm"

        "/dev/nvidia0"
        "/dev/nvidiactl"
        "/dev/nvidia-modeset"
        "/dev/nvidia-uvm"
      ];

      tmpfs = [
        "/tmp"
      ];

      env = {
        XDG_DATA_DIRS = lib.mkForce (
          lib.makeSearchPath "share" [
            iconTheme
            cursorTheme
            pkgs.shared-mime-info
          ]
        );
        XCURSOR_PATH = lib.mkForce (
          lib.concatStringsSep ":" [
            "${cursorTheme}/share/icons"
            "${cursorTheme}/share/pixmaps"
          ]
        );
      };
    };
  };
}
