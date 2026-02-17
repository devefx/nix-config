# NixOS desktop environment base configuration
{
  pkgs,
  myvars,
  lib,
  ...
}: {
  # Networking
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Niri Wayland Compositor ──────────────────────────────────
  programs.niri.enable = true;

  # Session manager (replaces SDDM)
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = myvars.username;
      command = "$HOME/.wayland-session";
    };
  };

  # XDG portal for file picker, screen sharing, etc.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Bluetooth
  services.blueman.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
}
