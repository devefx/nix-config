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
# Built from source rather than the upstream AppImage, whose bundled
# WebKitGTK aborts WebKitWebProcess with EGL errors on faex1 (blank/white
# window). The build compiles against nixpkgs' webkitgtk_4_1, where that
# crash does not reproduce.
#
# pkgs/cc-switch bumps nixpkgs' recipe from 3.16.5 (schema v11, unmoved
# since 2026-07) to upstream 3.20.4 (schema v19). The upgrade is a stepwise
# in-place migration, so the old requirement to delete
# ~/.cc-switch/cc-switch.db before launching no longer applies — but it is
# one-way: downgrading afterwards leaves a v19 database that 3.16.5 refuses
# to open. See pkgs/cc-switch/default.nix.
#
# Gated behind `modules.ccSwitch.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.ccSwitch;

  cc-switch = pkgs.callPackage ../../../../pkgs/cc-switch { };
in
{
  options.modules.ccSwitch = {
    enable = mkEnableOption "CC Switch desktop app (AI provider config manager)";
  };

  config = mkIf cfg.enable {
    home.packages = [ cc-switch ];
  };
}
