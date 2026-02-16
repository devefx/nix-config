# Cross-platform Home Manager configuration
# All .nix files in this directory are auto-imported.
{
  mylib,
  myvars,
  pkgs,
  ...
}: {
  imports = mylib.scanPaths ./.;

  home = {
    username = myvars.username;
    # homeDirectory is set per-platform in linux/ and darwin/
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Common user packages
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tree
    bat
    eza
    fzf
  ];

  home.stateVersion = "24.11";
}
