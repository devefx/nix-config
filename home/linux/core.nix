# Entry point for headless / CLI-only Linux hosts.
# Hosts import this directly (no default.nix, pick an entry explicitly).
{
  imports = [
    ../base/home.nix
    ../base/core
  ];
}
