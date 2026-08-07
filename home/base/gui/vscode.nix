{ pkgs, ... }:
# VS Code — Microsoft's cross-platform code editor.
#
# Packaged binary from nixpkgs (unfree — allowed by
# `nixpkgs.config.allowUnfree` in modules/base/nix.nix). Prefer a
# telemetry-free build? Swap for `vscodium`.
#
# Extensions are installed from the Extensions view for now (they live in
# ~/.vscode and survive rebuilds). Move to home-manager's
# `programs.vscode` if you want them pinned declaratively.
{
  home.packages = [ pkgs.vscode ];
}