# Wrapper around nixpkgs.lib.nixosSystem that auto-integrates
# home-manager as a NixOS module.
{inputs}: {
  system,
  specialArgs,
  nixos-modules,
  home-modules ? [],
}: let
  inherit (inputs) nixpkgs home-manager;
in
  nixpkgs.lib.nixosSystem {
    inherit system specialArgs;
    modules =
      nixos-modules
      ++ (
        if home-modules != []
        then [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = specialArgs;
              users.${specialArgs.myvars.username} = {
                imports = home-modules;
              };
            };
          }
        ]
        else []
      );
  }
