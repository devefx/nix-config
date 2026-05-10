# Placeholder — replace after running `sudo nixos-generate-config --dir /tmp/hw`
# inside the PVE VM itself.
#
# For a standard PVE VM with virtio-scsi / virtio-block + BIOS/UEFI, the
# generated file typically looks roughly like:
#
#   boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" ... ];
#   boot.initrd.kernelModules = [ ];
#   boot.kernelModules = [ "kvm-amd" ];   # or kvm-intel on Intel PVE nodes
#   fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
#   swapDevices = [ ];
{
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
    "virtio_blk"
    "ahci"
    "xhci_pci"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];
}
