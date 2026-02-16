# macOS (nix-darwin) specific modules
# All .nix files in this directory are auto-imported.
{mylib, ...}: {
  imports = mylib.scanPaths ./.;
}
