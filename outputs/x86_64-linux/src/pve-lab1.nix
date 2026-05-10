{ mylib, ... }@args:
let
  name = "pve-lab1";
  modules = {
    nixos-modules = map mylib.relativeToRoot [
      # Mandatory base (cross-platform + NixOS base).
      "modules/nixos"
      # Desktop module group — provides `modules.desktop.*` toggles.
      "modules/nixos/desktop"
      # PVE/KVM guest tuning — explicitly opted in for VM hosts.
      "modules/nixos/server/qemu-guest.nix"
      # Host-specific (hardware-configuration.nix, hostName, ...).
      "hosts/${name}"
      # Sandbox overlays — safe, pure namespace registration.
      "hardening/nixpaks"
      "hardening/bwraps"
    ];
    home-modules = map mylib.relativeToRoot [
      "home/hosts/${name}.nix"
    ];
  };
in
{
  nixosConfigurations = {
    "${name}" = mylib.nixosSystem (modules // args);
  };
}
