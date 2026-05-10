{
  self,
  nixpkgs,
  pre-commit-hooks,
  ...
}@inputs:
let
  inherit (inputs.nixpkgs) lib;
  mylib = import ../lib { inherit lib; };
  myvars = import ../vars;

  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib myvars;

      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    };

  args = {
    inherit
      inputs
      lib
      mylib
      myvars
      genSpecialArgs
      ;
  };

  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
  };
  allSystems = nixosSystems;
  allSystemNames = builtins.attrNames allSystems;
  nixosSystemValues = builtins.attrValues nixosSystems;

  forAllSystems = func: (nixpkgs.lib.genAttrs allSystemNames func);
in
{
  debugAttrs = {
    inherit nixosSystems allSystemNames;
  };

  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  packages = forAllSystems (system: allSystems.${system}.packages or { });

  evalTests = lib.lists.all (it: it.evalTests == { }) nixosSystemValues;

  checks = forAllSystems (system: {
    eval-tests = allSystems.${system}.evalTests == { };

    pre-commit-check = pre-commit-hooks.lib.${system}.run {
      src = mylib.relativeToRoot ".";
      hooks = {
        nixfmt-rfc-style = {
          enable = true;
          settings.width = 100;
        };
        typos = {
          enable = true;
          settings = {
            write = true;
            configPath = ".typos.toml";
          };
        };
        prettier = {
          enable = true;
          settings = {
            write = true;
            configPath = ".prettierrc.yaml";
          };
        };
      };
    };
  });

  devShells = forAllSystems (
    system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      default = pkgs.mkShell {
        packages = with pkgs; [
          bashInteractive
          gcc
          nixfmt-rfc-style
          deadnix
          statix
          typos
          nodePackages.prettier
        ];
        name = "nix-config";
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    }
  );

  formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
}
