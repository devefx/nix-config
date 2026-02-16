# Wrapper around nix-darwin that auto-integrates
# home-manager as a Darwin module.
{inputs}: {
  system,
  specialArgs,
  darwin-modules,
  home-modules ? [],
}: let
  inherit (inputs) nix-darwin home-manager;
in
  nix-darwin.lib.darwinSystem {
    inherit system specialArgs;
    modules =
      darwin-modules
      ++ (
        if home-modules != []
        then [
          home-manager.darwinModules.home-manager
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
