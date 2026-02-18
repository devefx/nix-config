{
  description = "My Nix configuration for NixOS and macOS";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-24.11";

    # macOS support
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Application sandboxing
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    # Import custom lib helpers
    mylib = import ./lib {inherit inputs; lib = nixpkgs.lib;};
    # Shared variables (username, SSH keys, etc.)
    myvars = import ./vars;

    # Systems to generate packages/shells for
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Common specialArgs passed to all modules
    specialArgs = {
      inherit inputs mylib myvars;
      nixpak = inputs.nixpak;
    };
  in {
    # ── Formatter ──────────────────────────────────────────────
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # ── Overlays ───────────────────────────────────────────────
    overlays = import ./overlays {inherit inputs;};

    # ── Custom packages ────────────────────────────────────────
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});

    # ── NixOS Configurations ───────────────────────────────────
    nixosConfigurations = {
      # FIXME: Replace "nixos-desktop" with your hostname
      nixos-desktop = mylib.nixosSystem {
        inherit specialArgs;
        system = "x86_64-linux";
        nixos-modules = [
          ./hosts/nixos-desktop
          ./modules/base
          ./modules/nixos
          ./hardening/nixpaks
          ./hardening/bwraps
          ./secrets/nixos.nix
        ];
        home-modules = [
          ./home/linux/gui.nix
        ];
      };
    };

    # ── macOS (nix-darwin) Configurations ──────────────────────
    darwinConfigurations = {
      # FIXME: Replace "darwin-laptop" with your hostname
      darwin-laptop = mylib.darwinSystem {
        inherit specialArgs;
        system = "aarch64-darwin";
        darwin-modules = [
          ./hosts/darwin-laptop
          ./modules/base
          ./modules/darwin
          ./secrets/darwin.nix
        ];
        home-modules = [
          ./home/darwin
        ];
      };
    };
  };
}
