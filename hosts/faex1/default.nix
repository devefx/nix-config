{ myvars, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "faex1";

  # This machine was installed with GRUB and dual-boots Windows 11
  # (Windows boot files live on the same ESP). Override the framework
  # default of systemd-boot.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev"; # UEFI-only: do not write to an MBR
    efiSupport = true;
    extraEntries = ''
      menuentry "Windows 11" {
        insmod part_gpt
        insmod fat
        insmod chain
        search --fs-uuid --set=root E28C-ED3A
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  boot.supportedFilesystems = [ "ntfs" ];

  # Shared NTFS data partition, mounted with the in-kernel ntfs3 driver.
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/7C02CBA602CB642C";
    fsType = "ntfs3";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
      "umask=022"
    ];
  };

  modules.desktop.plasma.enable = true;
  modules.desktop.gaming.enable = true;
  modules.desktop.fonts.enable = true;

  system.stateVersion = myvars.stateVersion;
}
