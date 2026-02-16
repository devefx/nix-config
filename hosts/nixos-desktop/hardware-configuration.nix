# Hardware configuration placeholder
# FIXME: Replace with output from `nixos-generate-config --show-hardware-config`
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # FIXME: Add your actual hardware configuration
  # boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  # fileSystems."/" = { device = "/dev/disk/by-uuid/..."; fsType = "ext4"; };
}
