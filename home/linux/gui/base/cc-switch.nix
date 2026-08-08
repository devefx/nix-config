{
  lib,
  pkgs,
  config,
  ...
}:
# CC Switch — desktop manager for AI provider configs (Claude Code /
# Codex / Gemini CLI): one-click provider switching, MCP / Skills sync,
# and local usage tracking.
#
# Uses the native `pkgs.cc-switch` from nixpkgs (v3.16.5, database schema
# v11) instead of the upstream AppImage, whose bundled WebKitGTK aborts
# WebKitWebProcess with EGL errors on faex1 (blank/white window). The
# nixpkgs build compiles against nixpkgs' webkitgtk_4_1 (2.52.5), where
# the upstream crash no longer reproduces.
#
# NOTE: nixpkgs' cc-switch (3.16.5) only reads database schema v11. A
# database migrated by newer releases (schema v16, from 3.18.0+) must be
# reset before launching: `rm ~/.cc-switch/cc-switch.db` (the app then
# recreates it and providers must be re-added). Once nixpkgs ships
# cc-switch >= 3.18.0, this NOTE no longer applies.
#
# Requires the `nixpkgs` (nixos-unstable) input to be at or after rev
# 38a4887 (2026-07-25); flake.lock is pinned there already.
#
# Gated behind `modules.ccSwitch.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.ccSwitch;
in
{
  options.modules.ccSwitch = {
    enable = mkEnableOption "CC Switch desktop app (AI provider config manager)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.cc-switch ];
  };
}
