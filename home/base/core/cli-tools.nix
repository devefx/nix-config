{ pkgs, ... }:
# Small CLI tools with NO home-manager `programs.<tool>` module — pure
# binary installs. Everything here is just `home.packages`.
#
# Rule of thumb:
#   - tool HAS `programs.<tool>` in home-manager → split to its own file
#     (see eza.nix / bat.nix / git.nix / starship.nix / direnv.nix)
#   - tool does NOT → bundle here
#
# Check via `nix repl` → `:lf <home-manager>` → `options.programs.<tool>`,
# or https://home-manager-options.extranix.com/.
{
  home.packages = with pkgs; [
    ripgrep # rg — fast grep (no programs.ripgrep)
    fd # modern find (no programs.fd)
    jq # json query (no programs.jq)
  ];
}
