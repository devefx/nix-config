{ modulesPath, lib, ... }:
# Module for NixOS running as a QEMU/KVM guest — tailored for Proxmox VE
# (PVE), but works for any virtio-based hypervisor (KubeVirt, libvirt,
# plain qemu, etc.).
#
# Explicitly imported by host files that need it — not auto-imported.
{
  imports = [
    "${toString modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {
    # qemu-guest-agent — lets the hypervisor query guest state and
    # trigger commands (shutdown, fs-freeze for backup consistency, etc.).
    services.qemuGuest.enable = true;

    # PVE VMs default to SeaBIOS, so the systemd-boot default from
    # base/core.nix won't work. Switch to GRUB on virtio disk. Override
    # grub.device in the host file if the VM uses SATA/IDE (/dev/sda).
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
    boot.loader.grub.enable = lib.mkDefault true;
    boot.loader.grub.device = lib.mkDefault "/dev/vda";

    # Auto-grow root partition when you resize the VM disk in PVE.
    boot.growPartition = lib.mkDefault true;

    # Serial console — enables PVE's noVNC serial tab and `qm terminal <id>`.
    boot.kernelParams = [ "console=ttyS0" ];
    systemd.services."serial-getty@ttyS0".enable = true;

    # SSH usually the only way in on a headless VM.
    services.openssh.enable = true;
  };
}
