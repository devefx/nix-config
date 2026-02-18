# Core CLI tools (cross-platform)
{pkgs, ...}: {
  home.packages = with pkgs; [
    ripgrep
    fd
    jq
    tree
    bat
    eza
    fzf
  ];
}
