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

    # Boot loader (systemd-boot vs grub) is host-specific — depends on
    # whether the VM is provisioned with OVMF (UEFI) or SeaBIOS. Leave
    # it to base/core.nix (systemd-boot by default, suits OVMF) or the
    # host file. Override to grub in `hosts/<name>/default.nix` for
    # SeaBIOS VMs.

    # Auto-grow root partition when you resize the VM disk in PVE.
    boot.growPartition = lib.mkDefault true;

    # Serial console — enables PVE's noVNC serial tab and `qm terminal <id>`.
    boot.kernelParams = [ "console=ttyS0" ];
    systemd.services."serial-getty@ttyS0".enable = true;

    # SSH usually the only way in on a headless VM.
    services.openssh.enable = true;
  };
}
