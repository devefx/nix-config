{
  myvars,
  lib,
  pkgs,
  ...
}:
let
  # GRUB theme — sandesh236/sleek--themes (MIT), pinned commit e103aa4
  # (2025-05-21). Variants: "Sleek theme-bigSur" / "-dark" / "-light" / "-orange" (default: light).
  grubTheme = pkgs.runCommand "sleek-grub-theme" {
    src = pkgs.fetchurl {
      url = "https://codeload.github.com/sandesh236/sleek--themes/tar.gz/e103aa4cd655be6a38dbab37b1911c6ed9ef7765";
      sha256 = "sha256-DbsGg5mcbPxew3UarMLQEMafS4CEXBt4K+oVt4NsGoY=";
    };
  } ''
    mkdir -p $out
    tar -xzf $src -C $out --strip-components=1
  '';
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
    theme = "${grubTheme}/Sleek theme-light/sleek";
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

  # Clash Verge with TUN mode: setuid wrapper + privilege service.
  # tunMode needs networking.firewall.checkReversePath to be loose (set automatically).
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
  system.stateVersion = myvars.stateVersion;
}
