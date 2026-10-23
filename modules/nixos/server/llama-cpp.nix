{
  config,
  lib,
  pkgs,
  myvars,
  ...
}:
# llama.cpp server (Vulkan backend) as a systemd unit, for the gguf-model-presets
# tree that also holds gufo's weights.
#
# Deliberately the mirror image of modules/nixos/server/gufo.nix on one point:
# gufo runs on every boot, this one does not. The two need the same ~85-90 GiB
# of unified memory and both want port 8080, so only one can be resident.
# Registering llama.cpp as a unit that starts on demand keeps the switch
# explicit:
#
#   sudo systemctl start llama-cpp     # after stopping gufo
#   sudo systemctl stop  llama-cpp     # before starting gufo
#
# The port differs on purpose: llama.cpp defaults to 9931 since v0.7.0 while
# gufo owns 8080, so a double start fails on memory rather than racing for the
# same socket.
#
# `enable` still defaults to false, so importing this file has no effect until a
# host opts in.
#
# Unlike gufo, llama.cpp handles model selection itself: `--models-preset` plus
# `--models-autoload` reads the INI below and loads whichever model a client
# asks for. That is why there is no `model` option here — the preset file is the
# model list.
let
  cfg = config.modules.llamaCppServer;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  # Same package the home module exposes, so the CLI and the service cannot
  # drift apart. This is nixpkgs' Vulkan build bumped to 0.7.0 for
  # `--moe-cache-mib`; see pkgs/llama-cpp-0.7/default.nix.
  package = pkgs.callPackage ../../../pkgs/llama-cpp-0.7 { };
in
{
  options.modules.llamaCppServer = {
    enable = mkEnableOption "llama.cpp server as a systemd unit (not started on boot)";

    package = mkOption {
      type = types.package;
      default = package;
      defaultText = lib.literalExpression "pkgs.callPackage ../../../pkgs/llama-cpp-0.7 { }";
      description = "llama.cpp package providing `llama-server`.";
    };

    presetsDir = mkOption {
      type = types.str;
      default = "/home/${myvars.username}/models-presets";
      defaultText = lib.literalExpression ''"/home/''${myvars.username}/models-presets"'';
      example = "/mnt/data/Shared/github/workspace/gguf-model-presets";
      description = ''
        Directory holding `models.ini`. It is resolved from the service's
        working directory, so a symlink keeps the same config working wherever
        the weights actually live:

        ```
        ln -s /mnt/data/Shared/github/workspace/gguf-model-presets ~/models-presets
        ```

        Each entry's `model =` path is relative to this directory.
      '';
    };

    presetFile = mkOption {
      type = types.str;
      default = "models.ini";
      description = "INI file inside `presetsDir` listing the models to serve.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address passed to `--host`.";
    };

    port = mkOption {
      type = types.port;
      default = 9931;
      description = ''
        Listen port. 9931 is llama.cpp's own default since v0.7.0, and picking
        it here keeps the two engines off each other's port: gufo owns 8080.
        They still cannot run together — the conflict is the ~85-90 GiB of
        unified memory, not the port — but an accidental double start now
        fails on memory alone instead of racing for the same socket.
      '';
    };

    apiKey = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Bearer token required by `--api-key`. `null` leaves the server open,
        which is only reasonable on a trusted network. Prefer pointing this at
        an agenix secret rather than writing the token into this repo.
      '';
    };

    user = mkOption {
      type = types.str;
      default = myvars.username;
      description = "Account running the server. Needs `/dev/dri/renderD*` access via the `render` group.";
    };

    moeCacheMib = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      example = 8192;
      description = ''
        GPU-side LRU cache size, in MiB, for MoE experts that live in host
        memory (`--moe-cache-mib`, new in llama.cpp 0.7.0). Experts are pulled
        into the cache on demand instead of being read from host memory for
        every token; upstream measures up to ~2.2x decode throughput when
        experts are offloaded.

        Only meaningful together with expert offloading (`--cpu-moe` or
        `--n-cpu-moe`), which is what makes a model larger than the GPU budget
        usable at all. `null` leaves the option off, which is right when the
        whole model already fits on the GPU.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--parallel"
        "1"
        "--jinja"
      ];
      description = "Extra arguments appended to `llama-server`.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open `port` when `host` is not a loopback address.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.optional (
      cfg.openFirewall && cfg.host != "127.0.0.1" && cfg.host != "localhost"
    ) cfg.port;

    systemd.services.llama-cpp = {
      description = "llama.cpp OpenAI-compatible server (Vulkan)";
      documentation = [ "https://github.com/ggml-org/llama.cpp/blob/master/docs/server.md" ];
      # No `wantedBy`: the unit is registered and can be started by hand, but
      # nothing pulls it in at boot. That is the whole point — see the header.
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = lib.escapeShellArgs (
          [
            "${cfg.package}/bin/llama-server"
            "--models-preset"
            cfg.presetFile
            "--models-autoload"
            "--host"
            cfg.host
            "--port"
            (toString cfg.port)
          ]
          ++ lib.optionals (cfg.apiKey != null) [
            "--api-key"
            cfg.apiKey
          ]
          ++ lib.optionals (cfg.moeCacheMib != null) [
            "--moe-cache-mib"
            (toString cfg.moeCacheMib)
          ]
          ++ cfg.extraArgs
        );
        User = cfg.user;
        Group = "users";
        # Vulkan needs the DRM render node; the `render` group gates it.
        SupplementaryGroups = [ "render" ];
        WorkingDirectory = cfg.presetsDir;
        # Loading a large GGUF takes a while on first touch.
        TimeoutStartSec = 600;
        Restart = "on-failure";
        RestartSec = 10;
        KillSignal = "SIGTERM";
        TimeoutStopSec = 60;
      };
    };
  };
}
