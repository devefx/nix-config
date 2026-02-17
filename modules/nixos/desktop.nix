# NixOS desktop environment base configuration
{
  pkgs,
  lib,
  ...
}: {
  # Networking
  networking.networkmanager.enable = true;

  # Timezone and locale
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Desktop Environment: KDE Plasma 6 ───────────────────────
  services = {
    xserver.enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma6.enable = true;
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
