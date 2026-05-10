{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "faex1";

  modules.desktop.plasma.enable = true;
  modules.desktop.gaming.enable = true;
  modules.desktop.fonts.enable = true;

  system.stateVersion = "25.11";
}
