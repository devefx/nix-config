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
# moved on; the flake input already tracks 1.2.0, so taking Pi from there
# keeps it current without adding another input.
#
# Pi Web (`pi-web`, pkgs/pi-web) is the community browser front end for that
# same agent — it reads the sessions and provider credentials the `pi` CLI
# already has, so it needs no separate login. Note it bundles its own copy of
# the Pi packages (1.2.0, the version upstream pins) instead of reusing the
# 1.2.0 CLI from the flake input; the two do not conflict.
#
# The server is long-lived, so `modules.aiAgents.piWeb` runs it as a systemd
# user service bound to `hostname`:`port` (default 0.0.0.0:30141). The CLI
# rejects positional arguments, so the project directory the UI starts in is
# set through systemd's `WorkingDirectory`, not a flag. Note pi-web serves
# plain HTTP: when `hostname` is not loopback, set `environmentFile` to a file
# exporting `PI_WEB_PASSWORD=...` (e.g. an agenix secret) or the UI is open to
# everyone who can reach the port.
#
# REA (`rea`, pkgs/rea-agents) is a CLI + MCP server for binary and
# application reverse engineering (https://github.com/morluto/rea). Upstream
# ships it through `npx -y rea-agents@<version>`, but that resolves the package
# over the network on every client startup and follows whatever the registry
# serves, so it is packaged and pinned here instead. Nothing is fetched at
# session start, and the whole thing works offline.
#
# `modules.aiAgents.rea` wires it into all four agents, each through the seam
# that agent actually offers:
#
#   * Pi and Pi Web share one registration. Pi has no config file it owns for
#     MCP servers (`~/.pi/agent/mcp.json` is written by `pi mcp add` and by
#     Pi Web's Add Server dialog), so the entry goes in an *extension* at
#     `~/.pi/agent/extensions/rea.ts`. Pi's SDK loads that directory in both
#     the CLI and Pi Web's in-process sessions, so a single file covers both.
#   * Codex and DSH keep their MCP list in files they write themselves, so a
#     store symlink would be clobbered: Codex persists user config from its
#     TUI (and the ChatGPT desktop app writes the same file), and DSH
#     documents `cordis.patch.yml` as the place for user overrides. Both are
#     handled by running REA's own `setup --client codex --client dsh` once
#     during activation, which already writes the absolute `scripts/rea.mjs`
#     path, records the discovered Ghidra/JDK paths in the entry's `env`,
#     preserves unrelated keys and comments, is idempotent, and backs the file
#     up first.
#
# The bundled `reverse-engineer-anything` skill goes to `~/.agents/skills`,
# which Pi, DSH (`dsh-skill-filesystem`) and Codex all discover.
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
  reaCfg = cfg.rea;

  codex-desktop = pkgs.callPackage ../../../pkgs/codex-desktop { };
  dsh-desktop = pkgs.callPackage ../../../pkgs/dsh-desktop { };
  pi-web = pkgs.callPackage ../../../pkgs/pi-web { };
  rea = pkgs.callPackage ../../../pkgs/rea-agents { };

  # Pi has no MCP registration file it owns; `~/.pi/agent/mcp.json` is only
  # written by `pi mcp add` and by REA's own setup, and pi-web's Add Server
  # dialog edits it as user data. An extension is the declarative seam: Pi
  # loads `~/.pi/agent/extensions/*.ts` in both the CLI and pi-web's SDK
  # sessions, and `pi.registerMcpServer` registers a server for the session
  # without touching mcp.json.
  #
  # Registration is session-scoped by design (Pi docs: "Registrations are not
  # saved: register again on every load"), so this is the supported way to
  # declare a server rather than a workaround.
  #
  # `env` carries the Ghidra paths instead of `home.sessionVariables`: REA is
  # the only consumer, and a global `JAVA_HOME` would collide with the Godot
  # Android module, which exports its own JDK 17 through that variable.
  reaEnv = lib.optionalAttrs reaCfg.ghidra {
    GHIDRA_INSTALL_DIR = "${pkgs.ghidra}/lib/ghidra";
    JAVA_HOME = pkgs.jdk21.home;
  };

  # Kept as its own line so the default (no Ghidra) extension stays minimal.
  reaEnvLine = lib.optionalString (reaEnv != { }) "\t\tenv: ${builtins.toJSON reaEnv},\n";

  reaExtension = pkgs.writeText "rea.ts" ''
    /**
     * REA MCP server registration. Managed by nix-config:
     * home/base/gui/ai-agents.nix (modules.aiAgents.rea).
     */
    export default function (pi) {
    	pi.registerMcpServer("rea", {
    		type: "stdio",
    		command: "${lib.getExe rea}",
    		args: ["mcp"],
    		description: "Reverse engineer binaries, applications and runtimes.",
    ${reaEnvLine}	});
    }
  '';

  # REA resolves the skill directory next to the agent directory rather than
  # through Pi's own loader, so the bundled skill is installed by hand. The
  # MCP server exposes the tools; the skill is only the usage instructions.
  reaSkill = pkgs.runCommand "rea-skill" { } ''
    mkdir -p $out
    cp -a ${rea}/libexec/rea-agents/skills/reverse-engineer-anything $out/
  '';

  # Ghidra, and the JDK 21 it runs on. The two consumers need different sets,
  # because the JDK cannot go into the profile:
  #
  # - `home.packages` takes Ghidra alone. Its launcher already carries the JDK
  #   it was built against: nixpkgs wraps `support/launch.sh` with
  #   `--prefix PATH : ${openjdk21}`, so the JDK is reachable without being
  #   installed separately.
  # - `rea-setup` takes both, because `rea` discovers Java by scanning `PATH`
  #   and records the path it finds in its own configuration.
  #
  # `jdk21` must NOT be added to `home.packages`: `modules.godotAndroid` installs
  # `openjdk17` there, both JDKs ship the same 28 names under `lib/openjdk/bin/`
  # (`java`, `javac`, `jar`, `keytool`, ...), and the `pkgs.buildEnv` that
  # home-manager uses for the profile aborts with "two given paths contain a
  # conflicting subpath" rather than picking one.
  reaGhidraProfile = with pkgs; [ ghidra ];
  reaGhidraSetupPath = with pkgs; [
    ghidra
    jdk21
  ];

  # REA's own `setup` already merges into those files correctly, so it is
  # called rather than reimplemented here: it writes the absolute
  # `scripts/rea.mjs` path, records the Ghidra/JDK paths it discovers in the
  # entry's `env`, preserves comments and unrelated keys, is idempotent, and
  # backs the file up before touching it.
  #
  # `--skill=false` because the skill is a `home.file` below, and `--yes`
  # because activation has no TTY. `runtimeInputs` carries Ghidra and the JDK
  # so that `rea` finds them on `PATH` and records them itself.
  #
  # Its plan report goes to stdout and is discarded; a failure still writes to
  # stderr and aborts the activation.
  reaSetup = pkgs.writeShellApplication {
    name = "rea-setup";
    # Ghidra and the JDK on `PATH` are how `rea` discovers them to record in the
    # generated entry, so they are added only when the option is on.
    runtimeInputs = [ rea ] ++ lib.optionals reaCfg.ghidra reaGhidraSetupPath;
    text = ''
      exec rea setup --client codex --client dsh --skill=false --yes
    '';
  };

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

    rea = {
      enable = mkEnableOption "REA (Reverse Engineer Anything) for Pi / Pi Web / Codex / DSH";

      ghidra = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Install Ghidra + JDK 21 and point REA at them, enabling the
          decompiler-backed tools. The paths reach the MCP server through its
          own `env` rather than the session environment, so they stay scoped to
          REA (a global `JAVA_HOME` would conflict with the Godot Android
          module, which exports its own JDK 17).

          REA does not install or manage Ghidra itself; it reads
          `GHIDRA_INSTALL_DIR` and `JAVA_HOME` from its own environment. It
          accepts Ghidra 12.1.x, which is what nixpkgs ships, and validates
          the native decompiler for the host architecture.
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
    ++ optionals pkgs.stdenv.hostPlatform.isLinux [ cc-haha-desktop ]
    ++ optionals reaCfg.enable ([ rea ] ++ optionals reaCfg.ghidra reaGhidraProfile);

    # The extension registers the server for every Pi session (CLI and
    # pi-web). It lives in the agent directory rather than under
    # `~/.config`, matching Pi's own layout.
    home.file = mkIf reaCfg.enable {
      ".pi/agent/extensions/rea.ts".source = reaExtension;
      ".agents/skills/reverse-engineer-anything".source = reaSkill;
    };

    # Codex and DSH read MCP servers from files they also write themselves, so
    # the entry is merged in place after `writeBoundary` (where home-manager has
    # finished creating the managed files). REA's own setup is idempotent, so
    # re-running a switch is a no-op.
    home.activation.reaMcpRegistration = mkIf reaCfg.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        verboseEcho "Registering REA as an MCP server for Codex and DSH"
        ${reaSetup}/bin/rea-setup >/dev/null
      ''
    );

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
