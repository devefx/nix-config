{
  lib,
  pkgs,
  llm-agents,
  config,
  ...
}:
# AI coding agent tooling — Codex CLI, DeepSeek Harness, Codex/ChatGPT
# desktop, plus the cc-haha desktop workspace.
#
# Codex and DeepSeek Harness (`dsh`) come from the `llm-agents.nix` flake
# input (pinned separately from nixpkgs so each vendor's supported version
# lands intact).
# Codex desktop comes from pkgs/codex-desktop, which extracts OpenAI's
# official Linux `.deb` and runs it through an FHS environment for NixOS.
# cc-haha (Claude Code Haha) is a desktop Claude Code workspace with no
# nixpkgs package, so we wrap its official Linux x86_64 AppImage release
# (pinned v0.6.8; sha512 taken from the release's latest-linux.yml).
#
# Gated behind `modules.aiAgents.enable` — only hosts that actually
# develop with these agents pull the ~GB of Node / Go / Rust runtimes
# bundled with them. Enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf optionals;

  cfg = config.modules.aiAgents;

  codex-desktop = pkgs.callPackage ../../../pkgs/codex-desktop { };

  cc-haha-icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/NanmiCoder/cc-haha/v0.6.8/desktop/src-tauri/icons/128x128.png";
    sha256 = "sha256-Te7Mr3uZATdT1RUleHdY9DN7gUtafwPHDtWN8zKxs0Q=";
  };

  cc-haha-appimage = pkgs.appimageTools.wrapType2 {
    pname = "cc-haha-appimage";
    version = "0.6.8";
    src = pkgs.fetchurl {
      url = "https://github.com/NanmiCoder/cc-haha/releases/download/v0.6.8/Claude-Code-Haha-0.6.8-linux-x86_64.AppImage";
      sha512 = "sha512-hIAS/XX9tEMs1LYi1oiYyIMkRaoWxSre4sC7PgWg+xd74FTo5IY3Vd0t5nJ6RyxPfB1EcpOk9RzAhOiSdrCYAQ==";
    };

    extraInstallCommands = ''
      install -Dm644 ${cc-haha-icon} $out/share/icons/hicolor/128x128/apps/cc-haha.png
    '';
  };

  # The desktop app is single-instance but does not reliably raise its
  # existing window. Focus the niri window first; only start a new process
  # when no window exists.
  cc-haha = pkgs.writeShellApplication {
    name = "cc-haha";
    runtimeInputs = [
      pkgs.jq
      pkgs.niri
    ];
    text = ''
      if command -v niri >/dev/null 2>&1; then
        window_id="$(
          niri msg --json windows 2>/dev/null |
            jq -r '[.[] | select(
              (.app_id // "") == "claude-code-desktop" or
              ((.title // "") | ascii_downcase | contains("claude code haha"))
            )] | first | .id // empty' 2>/dev/null
        )" || true

        if [[ -n "$window_id" ]] && niri msg action focus-window --id "$window_id" >/dev/null 2>&1; then
          exit 0
        fi
      fi

      exec ${lib.getExe cc-haha-appimage} "$@"
    '';
  };

  # Menu entry + binary, so Plasma picks it up as a desktop app.
  cc-haha-desktop = pkgs.buildEnv {
    name = "cc-haha-desktop";
    paths = [
      cc-haha-appimage
      cc-haha
      (pkgs.makeDesktopItem {
        name = "cc-haha";
        icon = "cc-haha";
        exec = "cc-haha";
        desktopName = "Claude Code Haha";
        comment = "Desktop Claude Code workspace";
        startupWMClass = "claude-code-desktop";
        categories = [
          "Development"
        ];
      })
    ];
  };
in
{
  options.modules.aiAgents = {
    enable = mkEnableOption "AI coding agent tooling (Codex CLI / DeepSeek Harness / desktop / cc-haha)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.dsh
      codex-desktop
    ]
    ++ optionals pkgs.stdenv.hostPlatform.isLinux [ cc-haha-desktop ];
  };
}
