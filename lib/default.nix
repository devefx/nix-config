# Custom lib helpers
{inputs, lib, ...}: {
  # Build a NixOS system with home-manager integrated
  nixosSystem = import ./nixosSystem.nix {inherit inputs;};

  # Build a macOS (nix-darwin) system with home-manager integrated
  darwinSystem = import ./darwinSystem.nix {inherit inputs;};

  # Auto-import all .nix files and directories in a path (excluding default.nix)
  # Adapted from: https://github.com/ryan4yin/nix-config/blob/main/lib/default.nix
  # Usage: imports = mylib.scanPaths ./.;
  scanPaths = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          name: _type:
          (_type == "directory")
          || (
            (name != "default.nix")
            && (lib.strings.hasSuffix ".nix" name)
          )
        ) (builtins.readDir path)
      )
    );
}
