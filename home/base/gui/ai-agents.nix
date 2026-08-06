{
  lib,
  pkgs,
  llm-agents,
  config,
  ...
}:
# AI coding agent tooling — Codex CLI, plus the cc-haha desktop workspace.
#
# Codex comes from the `llm-agents.nix` flake input (pinned separately
# from nixpkgs so each vendor's supported version lands intact).
# cc-haha (Claude Code Haha) is a desktop Claude Code workspace with no
# nixpkgs package, so we wrap its official Linux x86_64 AppImage release
# (pinned v0.5.3; sha512 taken from the release's latest-linux.yml).
#
# Gated behind `modules.aiAgents.enable` — only hosts that actually
# develop with these agents pull the ~GB of Node / Go / Rust runtimes
# bundled with them. Enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf optionals;

  cfg = config.modules.aiAgents;

  cc-haha = pkgs.appimageTools.wrapType2 {
    pname = "cc-haha";
    version = "0.5.3";
    src = pkgs.fetchurl {
      url = "https://github.com/NanmiCoder/cc-haha/releases/download/v0.5.3/Claude-Code-Haha-0.5.3-linux-x86_64.AppImage";
      sha512 = "sha512-68XfBFgvv9OmZDAzqSkcMnxQqHgMXCbFTIsaV6GbH5n6PVSoqfBW+F56UOxGaMVo2H0Ld8ewVJEuwywq3KkmvA==";
    };
  };

  # Menu entry + binary, so Plasma picks it up as a desktop app.
  cc-haha-desktop = pkgs.buildEnv {
    name = "cc-haha-desktop";
    paths = [
      cc-haha
      (pkgs.makeDesktopItem {
        name = "cc-haha";
        exec = "cc-haha";
        desktopName = "Claude Code Haha";
        comment = "Desktop Claude Code workspace";
        categories = [
          "Development"
          "Utility"
        ];
      })
    ];
  };
in
{
  options.modules.aiAgents = {
    enable = mkEnableOption "AI coding agent tooling (Codex / cc-haha)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ]
    ++ optionals pkgs.stdenv.hostPlatform.isLinux [ cc-haha-desktop ];
  };
}
