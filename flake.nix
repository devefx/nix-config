{
  description = "My Nix configuration";

  outputs = inputs: import ./outputs inputs;

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    godot-yoke = {
      url = "github:MHGameDevs/godot/yoke";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # GRUB theme — provides `boot.loader.grub2-theme` NixOS module.
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # directory -> attrset auto-loader
    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix code formatter + typo + prettier checks
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # declarative bubblewrap sandboxing for per-app isolation
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI coding agents — packages Claude Code / Codex / Gemini CLI / etc.
    # Does NOT follow our nixpkgs (agents pin their own supported versions).
    llm-agents.url = "github:numtide/llm-agents.nix";

    # age-encrypted secrets — asymmetric (age keys). Encrypted `.age` files
    # live in the private nix-secrets repo; decrypted at activation using the
    # host's SSH key.
    agenix = {
      url = "github:ryantm/agenix/4835b1dc898959d8547a871ef484930675cb47f1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Private secrets repo (git+ssh, must exist & be reachable from hosts):
    # https://github.com/devefx/nix-secrets
    mysecrets = {
      url = "git+ssh://git@github.com/devefx/nix-secrets.git?shallow=1";
      flake = false;
    };
  };
}
