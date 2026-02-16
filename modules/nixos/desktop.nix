# NixOS desktop environment base configuration
{
  pkgs,
  lib,
  ...
}: {
  # Networking
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "Asia/Shanghai"; # FIXME: your timezone
  i18n.defaultLocale = "en_US.UTF-8";

  # Audio (PipeWire)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
