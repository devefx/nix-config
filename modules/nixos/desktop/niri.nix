{
  config,
  lib,
  myvars,
  niri,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.niri;
in
{
  options.modules.desktop.niri = {
    enable = mkEnableOption "Niri Wayland compositor";
  };

  config = mkIf cfg.enable {
    # Niri's NixOS module supplies the session package, portals, polkit and
    # GNOME Keyring integration. X11 applications run through
    # xwayland-satellite on demand, so an Xorg server is not required.
    programs.niri.enable = true;
    programs.niri.package = niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;

    services.greetd = {
      enable = true;
      settings.default_session = {
        user = myvars.username;
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd $HOME/.wayland-session";
      };
    };

    hardware.graphics.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;

    services.printing.enable = true;

    # Thunar as the graphical file manager, matching the reference config.
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        thunar-archive-plugin
        thunar-volman
      ];
    };

    # Unlock the login keyring through greetd, matching the Plasma login path.
    security.pam.services.greetd.enableGnomeKeyring = true;
  };
}
