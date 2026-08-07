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
# Uses the native `pkgs.cc-switch` from nixpkgs (added 2026-06) instead of
# the upstream AppImage. The AppImage bundles an Ubuntu-built WebKitGTK
# that runs against NixOS host libraries and aborts WebKitWebProcess with
# EGL errors, leaving a blank/white window (seen on faex1). The nixpkgs
# build compiles against nixpkgs' webkitgtk_4_1 (2.52.5), where the
# upstream crash no longer reproduces.
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
