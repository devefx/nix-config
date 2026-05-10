# Entry point for Linux hosts with a graphical desktop.
# Layers: core + tui + base/gui (cross-platform GUI apps) + linux/gui (Linux-specific)
{
  imports = [
    ./tui.nix
    ../base/gui
    ./gui
  ];
}
