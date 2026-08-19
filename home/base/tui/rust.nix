{
  lib,
  pkgs,
  config,
  ...
}:
# Rust toolchain for Cargo development.
#
# nixpkgs tracks a single stable Rust release. If you need nightly or
# several toolchains, switch to `rustup` and manage them manually.
#
# Gated behind `modules.rust.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.rust;
in
{
  options.modules.rust = {
    enable = mkEnableOption "Rust toolchain (cargo, rustc, clippy, rustfmt, rust-analyzer)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      cargo # build system / package manager
      rustc # compiler
      rust-analyzer # language server
      clippy # lints
      rustfmt # formatter
    ];
  };
}
