# Linux-specific Home Manager configuration
# All .nix files in this directory are auto-imported.
{
  mylib,
  myvars,
  pkgs,
  ...
}: {
  imports = mylib.scanPaths ./.;

  home.homeDirectory = "/home/${myvars.username}";

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
