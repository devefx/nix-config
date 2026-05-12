{ pkgs, ... }:
{
  # System-wide CLI tools — available to all users and to root / sudo
  # shells (which don't see home-manager packages). Keep this list
  # minimal; user-specific dev tools belong in home/base/core/.
  environment.systemPackages = with pkgs; [
    curl
    wget
    git
    vim
    btop # process viewer — available even for root / in rescue shell
    just # Justfile runner — needed for `just switch`, `just build`, etc.
  ];
}
