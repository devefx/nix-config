{ myvars, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "pve-lab1";

  # KDE Plasma 6 desktop — same as faex1. Access via PVE's noVNC /
  # SPICE console, or install a SPICE client on your workstation.
  modules.desktop.plasma.enable = true;
  modules.desktop.fonts.enable = true;

  # SPICE vdagent — clipboard sharing + auto-resize with PVE's SPICE
  # console. Safe no-op if you only use the basic noVNC console.
  services.spice-vdagentd.enable = true;

  # Keep firewall tight — KDE runs locally, doesn't need extra ports.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  system.stateVersion = myvars.stateVersion;
}
