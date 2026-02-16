# Clash Verge Rev — proxy client (NixOS only)
# On macOS, install via Homebrew cask in hosts/darwin-laptop/default.nix
{
  pkgs,
  lib,
  ...
}: {
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    tunMode = true;
    autoStart = true;
  };
}
