{
  rust-overlay,
  lib,
  pkgs,
  config,
  ...
}:
# Rust toolchain for Cargo development.
#
# rust-overlay lets us extend the default toolchain with extra targets.
# `aarch64-linux-android` is needed for 64-bit ARM Android builds.
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.rust;

  rustPkgs = pkgs.extend rust-overlay.overlays.default;

  rustToolchain = rustPkgs.rust-bin.stable.latest.default.override {
    extensions = [ "rust-analyzer" ];
    targets = [ "aarch64-linux-android" ];
  };
in
{
  options.modules.rust = {
    enable = mkEnableOption "Rust toolchain (cargo, rustc, clippy, rustfmt, rust-analyzer)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      rustToolchain
    ];
  };
}
