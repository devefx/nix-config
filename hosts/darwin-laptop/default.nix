# macOS (nix-darwin) host configuration
{
  inputs,
  myvars,
  pkgs,
  ...
}: {
  # Auto-install Nix daemon service
  services.nix-daemon.enable = true;

  # Used for backward compatibility
  system.stateVersion = 5;

  # macOS user (nix-darwin manages this declaratively)
  users.users.${myvars.username} = {
    home = "/Users/${myvars.username}";
    description = myvars.userfullname;
  };

  # Homebrew integration for GUI apps not in nixpkgs
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "clash-verge-rev" # Proxy client (nixpkgs version is Linux-only)
      # "firefox"
      # "raycast"
    ];
  };
}
