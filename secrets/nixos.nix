# sops-nix secrets declarations (NixOS)
# See: https://github.com/Mic92/sops-nix
{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;

    age = {
      # Use the host SSH key to derive the age key automatically
      sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };
  };

  # Declare your secrets below. Each becomes a file under /run/secrets/
  # sops.secrets.example-secret = {};
  # sops.secrets."db/password" = {
  #   owner = config.users.users.youruser.name;
  # };
}
