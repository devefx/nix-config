# sops-nix secrets declarations (macOS / nix-darwin)
# See: https://github.com/Mic92/sops-nix
{
  inputs,
  myvars,
  ...
}: {
  imports = [
    inputs.sops-nix.darwinModules.sops
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;

    age = {
      # On macOS there is no SSH host key, specify your age key file explicitly
      keyFile = "/Users/${myvars.username}/.config/sops/age/keys.txt";
    };
  };

  # Declare your secrets below. Each becomes a file under /run/secrets/
  # sops.secrets.example-secret = {};
}
