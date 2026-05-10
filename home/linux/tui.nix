# Entry point for terminal-focused Linux hosts.
# Layers: core (CLI baseline) + tui (interactive terminal tools)
{
  imports = [
    ./core.nix
    ../base/tui
  ];
}
