{ mylib, ... }:
# Cross-platform GUI home-manager bits.
# Put apps here that run on both Linux and macOS (Firefox, VS Code,
# Obsidian, etc.). Linux-only GUI bits live in home/linux/gui/.
{
  imports = mylib.scanPaths ./.;
}
