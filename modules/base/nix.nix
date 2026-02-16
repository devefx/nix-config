# Nix core settings — shared between NixOS and Darwin
{
  inputs,
  lib,
  pkgs,
  ...
}: let
  flakeInputs = lib.filterAttrs (_: v: lib.isType "flake" v) inputs;
in {
  nix = {
    settings = {
      # Enable flakes and the new `nix` CLI
      experimental-features = ["nix-command" "flakes"];
      # Avoid garbage collection of build-time dependencies
      keep-outputs = true;
      keep-derivations = true;
      # Trusted users for remote builds
      trusted-users = ["root" "@wheel"];

      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      # substituters that will be considered before the official ones(https://cache.nixos.org)
      substituters = [
        # cache mirror located in China
        # status: https://mirrors.ustc.edu.cn/status/
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        # status: https://mirror.sjtu.edu.cn/
        # "https://mirror.sjtu.edu.cn/nix-channels/store"
        # others
        # "https://mirrors.sustech.edu.cn/nix-channels/store"
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"

        "https://nix-community.cachix.org"
      ];

      builders-use-substitutes = true;
    };

    # Make `nix run nixpkgs#xxx` use the same nixpkgs as this flake
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    # Make `nix repl '<nixpkgs>'` use the same nixpkgs as this flake
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

    # Garbage collection
    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Apply custom overlays
  nixpkgs.overlays = [
    inputs.self.overlays.additions
    inputs.self.overlays.modifications
    inputs.self.overlays.unstable-packages
  ];
}
