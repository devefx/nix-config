# NixOS desktop host configuration
# Compose modules here to build your system.
{
  inputs,
  myvars,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "yoke-nixos";

  # User account
  users.users.${myvars.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    openssh.authorizedKeys.keys = myvars.sshAuthorizedKeys;
  };

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.11";
}
