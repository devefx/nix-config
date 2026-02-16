# Cross-platform base modules (shared by NixOS and Darwin)
# All .nix files in this directory are auto-imported.
{mylib, ...}: {
  imports = mylib.scanPaths ./.;
}
