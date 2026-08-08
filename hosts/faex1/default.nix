{
  config,
  myvars,
  lib,
  pkgs,
  ...
}:
let
  # Build a CIFS mount for a server share. `cred` is the agenix-decrypted
  # credentials file path for that server.
  smbMount = server: cred: share: {
    device = "//${server}/${share}";
    fsType = "cifs";
    options = [
      "credentials=${cred}"
      # Mount lazily on first access instead of failing at boot before the
      # network/NAS is ready. `_netdev` alone did not add the needed
      # network-online ordering in the generated mount units.
      "x-systemd.automount"
      "noauto"
      "x-systemd.requires=network-online.target"
      "x-systemd.after=network-online.target"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "x-systemd.idle-timeout=300"
      "nofail"
      "_netdev"
      "rw"
      "uid=1000"
      "gid=100"
      "iocharset=utf8"
    ];
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "faex1";

  # Bluetooth — required for the KDE Bluetooth settings panel to show up.
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  # BlueZ 5.86 fails to activate A2DP on some speakers with
  # "a2dp-sink profile connect failed: Device or resource busy".
  # Pin 5.84 until nixpkgs ships the fixed 5.87 release.
  # https://github.com/bluez/bluez/issues/1898
  hardware.bluetooth.package = lib.mkIf (lib.versionOlder pkgs.bluez.version "5.87") (
    (pkgs.bluez.override {
      bluez-headers = pkgs.bluez-headers.overrideAttrs (old: {
        version = "5.84";

        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/bluetooth/bluez-5.84.tar.xz";
          hash = "sha256-W6c9Aw97AAh9Z4ALDjIWAa7A+JKCfHLlosg5DYyIaxE=";
        };
      });
    }).overrideAttrs
      (_: {
        patches = [
          (pkgs.fetchurl {
            name = "static.patch";
            url = "https://lore.kernel.org/linux-bluetooth/20250703182908.2370130-1-hi@alyssa.is/raw";
            hash = "sha256-4Yz3ljsn2emJf+uTcJO4hG/YXvjERtitce71TZx5Hak=";
          })
        ];
      })
  );
  # This machine was installed with GRUB and dual-boots Windows 11
  # (Windows boot files live on the same ESP). Override the framework
  # default of systemd-boot.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev"; # UEFI-only: do not write to an MBR
    efiSupport = true;
    extraEntries = ''
      menuentry "Windows 11" --class windows {
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

  # GRUB theme — vinceliuice/grub2-themes via its NixOS module (README method).
  # Variants: tela / vimix / stylish / whitesur · icons: color / white / whitesur
  # · screens: 1080p / 2k / 4k / ultrawide / ultrawide2k.
  boot.loader.grub2-theme = {
    enable = true;
    theme = "tela";
    icon = "white";
    screen = "4k";
  };

  boot.supportedFilesystems = [
    "ntfs"
    "cifs"
  ];

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

  # SMB shares — TrueNAS (192.168.16.251) and Windows Server
  # (192.168.16.206). Credentials are decrypted by agenix
  # (see secrets/nixos.nix).
  fileSystems."/mnt/portable_apps" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "portable_apps";
  fileSystems."/mnt/media" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "media";
  fileSystems."/mnt/downloads" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "downloads";
  fileSystems."/mnt/archive" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "archive";
  fileSystems."/mnt/workspace" =
    smbMount "192.168.16.251" config.age.secrets.smb-credentials.path
      "workspace";
  fileSystems."/mnt/wd_20t" =
    smbMount "192.168.16.206" config.age.secrets.smb-credentials-wd20t.path
      "wd_20t";

  modules.secrets.enable = true;
  modules.secrets.smb.enable = true;
  modules.desktop.plasma.enable = true;
  modules.desktop.gaming.enable = true;
  modules.desktop.fonts.enable = true;

  # Clash Verge with TUN mode: setuid wrapper + privilege service.
  # tunMode needs networking.firewall.checkReversePath to be loose (set automatically).
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
  system.stateVersion = myvars.stateVersion;
}
