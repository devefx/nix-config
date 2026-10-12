{
  lib,
  pkgs,
  llm-agents,
  config,
  ...
}:
# AI coding agent tooling — Codex CLI, DeepSeek Harness, Pi, Pi Web,
# DSH Desktop, Codex/ChatGPT desktop, plus the cc-haha desktop workspace.
#
# Codex, DeepSeek Harness (`dsh`) and Pi (`pi`) come from the
# `llm-agents.nix` flake input (pinned separately from nixpkgs so each
# vendor's supported version lands intact).
#
# Pi is the official `github.com/earendil-works/pi` coding agent (the npm
# package is `@earendil-works/pi-coding-agent`). nixpkgs also ships it as
# `pi-coding-agent`, but that copy is pinned to 0.85.1 while the vendor has
# moved on; the flake input already tracks 1.0.0, so taking Pi from there
# keeps it current without adding another input.
#
# Pi Web (`pi-web`, pkgs/pi-web) is the community browser front end for that
# same agent — it reads the sessions and provider credentials the `pi` CLI
# already has, so it needs no separate login. Note it bundles its own copy of
# the Pi packages (1.1.0, the version upstream pins) instead of reusing the
# 1.0.0 CLI from the flake input; the two do not conflict.
#
# The server is long-lived, so `modules.aiAgents.piWeb` runs it as a systemd
# user service bound to `hostname`:`port` (default 0.0.0.0:30141). The CLI
# rejects positional arguments, so the project directory the UI starts in is
# set through systemd's `WorkingDirectory`, not a flag. Note pi-web serves
# plain HTTP: when `hostname` is not loopback, set `environmentFile` to a file
# exporting `PI_WEB_PASSWORD=...` (e.g. an agenix secret) or the UI is open to
# everyone who can reach the port.
#
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
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optionals
    types
    ;

  cfg = config.modules.aiAgents;
  piWebCfg = cfg.piWeb;

  codex-desktop = pkgs.callPackage ../../../pkgs/codex-desktop { };
  dsh-desktop = pkgs.callPackage ../../../pkgs/dsh-desktop { };
  pi-web = pkgs.callPackage ../../../pkgs/pi-web { };

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
    enable = mkEnableOption "AI coding agent tooling (Codex CLI / DeepSeek Harness / Pi / Pi Web / desktop / cc-haha)";

    piWeb = {
      enable = mkEnableOption "the Pi Web server as a systemd user service";

      hostname = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = ''
          Address Pi Web binds to. The default exposes it on every interface,
          which requires a password — see `environmentFile`.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 30141;
        description = "TCP port Pi Web listens on.";
      };

      workingDirectory = mkOption {
        type = types.str;
        default = config.home.homeDirectory;
        description = ''
          Directory Pi Web starts in. Pi Web has no CLI flag for this, so it is
          passed to systemd as `WorkingDirectory`.
        '';
      };

      environmentFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/run/agenix/pi-web";
        description = ''
          Runtime file of `KEY=value` lines sourced by the service. Use it to
          inject `PI_WEB_PASSWORD` (and any `PI_WEB_*` overrides) without
          putting secrets in the Nix store.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.dsh
      llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
      pi-web
      codex-desktop
      dsh-desktop
    ]
    ++ optionals pkgs.stdenv.hostPlatform.isLinux [ cc-haha-desktop ];

    systemd.user.services.pi-web = mkIf (pkgs.stdenv.hostPlatform.isLinux && piWebCfg.enable) {
      Unit = {
        Description = "Pi Web — web UI for the Pi coding agent";
        After = [ "network.target" ];
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pi-web)
          "--hostname ${piWebCfg.hostname}"
          "--port ${toString piWebCfg.port}"
          "--no-open"
        ];
        WorkingDirectory = piWebCfg.workingDirectory;
        # `--no-open` only covers the CLI flag; the env var also keeps the
        # browser opener quiet if a future version re-reads it.
        Environment = [ "PI_WEB_NO_OPEN=1" ];
        Restart = "on-failure";
        RestartSec = 3;
      }
      // lib.optionalAttrs (piWebCfg.environmentFile != null) {
        EnvironmentFile = piWebCfg.environmentFile;
      };
    };
  };
}
