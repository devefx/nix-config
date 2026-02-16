# macOS-specific Home Manager configuration
# All .nix files in this directory are auto-imported.
{
  mylib,
  myvars,
  pkgs,
  ...
}: {
  imports = mylib.scanPaths ./.;

  home.homeDirectory = "/Users/${myvars.username}";
}
