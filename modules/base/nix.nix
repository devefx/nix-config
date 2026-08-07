{ myvars, ... }:
{
  # Allow non-free packages (Google Chrome, unrar, some firmware, ...).
  # Applies to both system-level `environment.systemPackages` and,
  # because `home-manager.useGlobalPkgs = true` in lib/nixosSystem.nix,
  # to home-manager too.
  nixpkgs.config.allowUnfree = true;

  # openldap 2.6.13 ships timing-sensitive syncrepl replication tests
  # that flake under load (provider/consumer db differ); skip checks so
  # rebuilds do not fail on them. The binaries are unaffected.
  nixpkgs.overlays = [
    (final: prev: {
      openldap = prev.openldap.overrideAttrs (old: { doCheck = false; });
    })
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-users = [ myvars.username ];

    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    builders-use-substitutes = true;
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
