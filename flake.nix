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
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/master";
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

    # AyuGram Desktop — Telegram fork with privacy extensions. Packaged
    # by upstream (not nixpkgs) so the flake has submodules; use git
    # input type. Binary cache: cache.garnix.io + ayugram-desktop.cachix.org
    # (public keys wired in modules/base/nix.nix).
    ayugram-desktop = {
      type = "git";
      submodules = true;
      url = "https://github.com/ndfined-crp/ayugram-desktop/";
    };
  };
}
