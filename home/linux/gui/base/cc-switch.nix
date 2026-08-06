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
# No nixpkgs package in the pinned channel (upstream added it 2026-05,
# after our lock date), so we wrap the official Linux x86_64 AppImage
# from the pinned v3.19.2 release. After a `nix flake update`, this can
# be swapped for plain `pkgs.cc-switch`.
#
# Gated behind `modules.ccSwitch.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.ccSwitch;

  cc-switch = pkgs.appimageTools.wrapType2 {
    pname = "cc-switch";
    version = "3.19.2";
    src = pkgs.fetchurl {
      url = "https://github.com/farion1231/cc-switch/releases/download/v3.19.2/CC-Switch-v3.19.2-Linux-x86_64.AppImage";
      sha256 = "sha256-3hnQR9+YP6bwXW+t378LOH3f9aV1yegOCjfJ+XN/EXU=";
    };
  };
in
{
  options.modules.ccSwitch = {
    enable = mkEnableOption "CC Switch desktop app (AI provider config manager)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.buildEnv {
        name = "cc-switch-desktop";
        paths = [
          cc-switch
          (pkgs.makeDesktopItem {
            name = "cc-switch";
            exec = "cc-switch";
            desktopName = "CC Switch";
            comment = "AI provider config manager for Claude Code / Codex / Gemini";
            categories = [ "Development" "Utility" ];
          })
        ];
      })
    ];
  };
}