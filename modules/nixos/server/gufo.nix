{
  config,
  lib,
  pkgs,
  gufo,
  myvars,
  ...
}:
# Gufo — local inference engine specialised for AMD Strix Halo (gfx1151).
# https://github.com/gufo-org/gufo
#
# The package comes straight from the upstream flake (`gufo`, pinned to a
# release tag in flake.nix, injected by genSpecialArgs). Only `gufo`'s own
# nixpkgs is replaced by ours, so the HIP/ROCr stack Gufo links against is the
# exact same ROCm the rest of the system ships — mixing two ROCm versions across
# one process tree is how you get "Memory critical" / device-probe failures.
#
# Prerequisites this module assumes (both already true on faex1):
#   - the user is in the `render` and `video` groups (modules/nixos/base/user-group.nix)
#   - `ttm.pages_limit` is raised so the iGPU can map tens of GiB of GTT
#     (hosts/faex1/default.nix raises it to 96 GiB)
#
# Model weights are NOT part of the store — they are ~104 GiB of GGUF. The
# module never fetches or creates them; it only points at them. Default paths
# are resolved under `modules.gufo.modelsDir` (default `~/models`), which is
# expected to be a symlink to wherever the weights actually live:
#
#   ~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL/
#   ├── UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-0000{1..4}-of-00004.gguf
#   ├── MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
#   └── mmproj-BF16.gguf
#
#   ln -s /mnt/data/Shared/github/workspace/gguf-model-presets/models ~/models
#
# Fetch recipe (the shards and the sidecars are separate `hf` calls — mixing
# explicit filenames with `--include` makes hf ignore the glob):
#
#   D=~/models/Qwen3.8-Flash-Next-UD-Q4_K_XL
#   R=38bb39ee97821de2c9009abb7e93950eec396e66
#   hf download unsloth/Qwen3.8-Flash-Next-GGUF \
#     --revision $R --include "UD-Q4_K_XL/*" --local-dir "$D"
#   hf download unsloth/Qwen3.8-Flash-Next-GGUF \
#     --revision $R --local-dir "$D" \
#     MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf mmproj-BF16.gguf
#
# Verified shard 1/4 sha256 against upstream's docs/models/qwen3.8-flash-next/
# artifacts/model-identities.json.
let
  cfg = config.modules.gufo;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  system = pkgs.stdenv.hostPlatform.system;

  upstream = gufo.packages.${system}.default;

  # Default model paths are derived from `modelsDir` so the tree can live
  # anywhere (a symlink into the home directory, an external disk, ...) without
  # editing three options. Nothing here is created by the module: the directory
  # and its contents are the operator's to provide.
  flashNextDir = "${cfg.modelsDir}/Qwen3.8-Flash-Next-UD-Q4_K_XL";
  defaultModel = "${flashNextDir}/UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-00001-of-00004.gguf";
  defaultMmproj = "${flashNextDir}/mmproj-BF16.gguf";
  defaultMtpModel = "${flashNextDir}/MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf";

  # `speculative = "mtp"` without a predictor would be rejected at startup, so
  # the flag pair is derived from whether an MTP model was given.
  speculativeArgs = lib.optionals (cfg.speculative != "off") (
    [
      "--speculative"
      cfg.speculative
    ]
    ++ lib.optional (cfg.mtpModel != null) "--mtp-model"
    ++ lib.optional (cfg.mtpModel != null) cfg.mtpModel
    ++ lib.optional (cfg.draftTokens != null) "--draft-tokens"
    ++ lib.optional (cfg.draftTokens != null) (toString cfg.draftTokens)
  );

  cacheArgs = lib.optionals cfg.cacheDisk.enable [
    "--cache-disk"
    "/var/lib/gufo/cache"
    "--cache-disk-bytes"
    (toString cfg.cacheDisk.bytes)
  ];

  serveArgs = [
    "serve"
    "--host"
    cfg.host
    "--port"
    (toString cfg.port)
    "--sessions"
    (toString cfg.sessions)
    "llm"
    "--model"
    cfg.model
    "--context"
    (toString cfg.context)
    "--served-model-name"
    cfg.servedModelName
  ]
  ++ lib.optionals (cfg.mmproj != null) [
    "--mmproj"
    cfg.mmproj
  ]
  ++ lib.optionals (cfg.think != null) [
    "--think"
    cfg.think
  ]
  ++ lib.optionals (cfg.reasoningEffort != null) [
    "--reasoning-effort"
    cfg.reasoningEffort
  ]
  ++ lib.optionals (cfg.preserveThinking != null) [
    "--preserve-thinking"
    cfg.preserveThinking
  ]
  ++ speculativeArgs
  ++ cacheArgs
  ++ lib.optional cfg.enableYarn "--enable-yarn"
  ++ cfg.extraArgs;
in
{
  options.modules.gufo = {
    enable = mkEnableOption "Gufo local inference server (Strix Halo / gfx1151)";

    package = mkOption {
      type = types.package;
      default = upstream;
      defaultText = lib.literalExpression "gufo.packages.${system}.default";
      description = ''
        Gufo package. Defaults to the upstream flake output; override to build
        from a local checkout while hacking on the engine.
      '';
    };

    modelsDir = mkOption {
      type = types.str;
      default = "/home/${myvars.username}/models";
      defaultText = lib.literalExpression ''"/home/''${myvars.username}/models"'';
      example = "/mnt/data/models";
      description = ''
        Directory the default `model`, `mmproj` and `mtpModel` paths are
        resolved under. Expected layout:

        ```
        <modelsDir>/Qwen3.8-Flash-Next-UD-Q4_K_XL/
        ├── UD-Q4_K_XL/Qwen3.8-Flash-Next-UD-Q4_K_XL-0000{1..4}-of-00004.gguf
        ├── MTP/mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf
        └── mmproj-BF16.gguf
        ```

        This module never creates the directory or the weights. Point it at a
        symlink (e.g. `~/models -> /mnt/data/...`) and the resolved paths stay
        stable across wherever the weights actually live.
      '';
    };

    model = mkOption {
      type = types.str;
      default = defaultModel;
      defaultText = lib.literalExpression "''${flashNextDir}/UD-Q4_K_XL/…-00001-of-00004.gguf";
      description = ''
        Path to the **first** shard of the target GGUF. Gufo discovers the
        remaining shards from its filename.
      '';
    };

    mmproj = mkOption {
      type = types.nullOr types.str;
      default = defaultMmproj;
      defaultText = lib.literalExpression "''${flashNextDir}/mmproj-BF16.gguf";
      description = ''
        BF16 vision projector. Set explicitly rather than relying on
        auto-discovery: the target shards live in the `UD-Q4_K_XL/`
        subdirectory while the projector sits in its parent, so the lookup only
        works through the parent-directory fallback. `null` re-enables that
        discovery (beside the target or one level up).
      '';
    };

    speculative = mkOption {
      type = types.enum [
        "mtp"
        "off"
      ];
      default = "mtp";
      description = ''
        Speculative decoding mode. Flash-Next supports MTP only; set `"off"`
        for plain autoregressive decoding (no predictor state is allocated).
      '';
    };

    mtpModel = mkOption {
      type = types.nullOr types.str;
      default = defaultMtpModel;
      defaultText = lib.literalExpression "''${flashNextDir}/MTP/mtp-…-shared-Q8_0.gguf";
      description = "Shared-Q8_0 MTP predictor; required when `speculative = \"mtp\"`.";
    };

    draftTokens = mkOption {
      type = types.nullOr (types.ints.between 1 7);
      default = null;
      description = ''
        Cap on drafted tokens per step. `null` keeps the default adaptive
        policy, which is what upstream benchmarks use.
      '';
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Bind address. The API is OpenAI-compatible and unauthenticated unless `extraArgs` adds `--api-key`.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Listen port; opened in the firewall when bound to a non-loopback address.";
    };

    sessions = mkOption {
      type = types.ints.positive;
      default = 2;
      description = ''
        Concurrent request slots. Each extra session costs about 1.06 GiB on
        Flash-Next (measured), independent of context length.
      '';
    };

    context = mkOption {
      type = types.ints.positive;
      default = 32768;
      description = ''
        Per-session context capacity. Native is 262144 and YaRN is unsupported.
        Admission reserves the whole capacity up front, so this is the main knob
        deciding whether the model fits.

        Measured on a 96 GiB GTT Strix Halo with Flash-Next Q4: 1x32768 uses
        84.25 GiB, 2x32768 85.31 GiB, 1x131072 86.76 GiB, 1x262144 90.12 GiB.
        KV costs about 26.8 MiB per 1K tokens, on top of ~82.4 GiB of weights.
      '';
    };

    enableYarn = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable static YaRN context extension. Required for `context` above
        262144 (the model's native maximum); `gufo serve` refuses to start
        above that without it, and the flag is an error at or below it.

        The extension factor is `context / 262144`, and it applies to every
        request on the server, including short ones. Attention cost also grows:
        prefill past 262144 tokens drops from the fused WMMA kernel to the
        per-token kernel. Memory is about 27.5 KiB per context token, so
        409600 tokens needs roughly 94 GiB of the 96 GiB GTT here — check
        headroom before raising `context`.
      '';
    };

    servedModelName = mkOption {
      type = types.str;
      default = "qwen3.8-flash-next";
      description = "Name clients pass in the `model` field (cosmetic, `/v1/models`).";
    };

    think = mkOption {
      type = types.nullOr (
        types.enum [
          "on"
          "off"
          "auto"
        ]
      );
      default = null;
      description = "Reasoning output default. `null` keeps the model template default (thinking on).";
    };

    reasoningEffort = mkOption {
      type = types.nullOr (
        types.enum [
          "auto"
          "minimal"
          "low"
          "medium"
          "high"
          "xhigh"
          "max"
        ]
      );
      default = null;
      description = "Reasoning depth instruction. `null` keeps the model default (`xhigh`).";
    };

    preserveThinking = mkOption {
      type = types.nullOr (
        types.enum [
          "on"
          "off"
          "auto"
        ]
      );
      default = null;
      description = "Whether earlier turns' thinking stays in the history (costs context).";
    };

    cacheDisk = {
      enable = mkEnableOption "restart-safe on-disk prompt-state cache";

      bytes = mkOption {
        type = types.ints.positive;
        default = 32 * 1024 * 1024 * 1024;
        description = "Maximum size of the disk cache. One server must own one directory.";
      };
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "--api-key"
        "local"
        "--max-pending-per-client"
        "8"
      ];
      description = "Extra arguments appended to `gufo serve`, after the modelled flags.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Environment variables for the service (e.g. `GUFO_HIPBLASLT_PLAN_CACHE`).";
    };

    user = mkOption {
      type = types.str;
      default = myvars.username;
      description = "Account running the server. Must be able to open `/dev/kfd` and `/dev/dri/renderD*`.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open `port` when `host` is not a loopback address.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.speculative == "off" || cfg.mtpModel != null;
        message = "modules.gufo: `speculative = \"mtp\"` needs `mtpModel`, or set `speculative = \"off\"`.";
      }
      {
        # Mirrors the server's own check so a bad combination fails at build
        # time instead of leaving the unit in a restart loop.
        assertion = cfg.context <= 262144 || cfg.enableYarn;
        message = "modules.gufo: `context` above 262144 needs `enableYarn = true`.";
      }
      {
        assertion = cfg.context > 262144 || !cfg.enableYarn;
        message = "modules.gufo: `enableYarn` has no effect at or below context 262144, and the server rejects it there.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.optional (
      cfg.openFirewall && cfg.host != "127.0.0.1" && cfg.host != "localhost"
    ) cfg.port;

    systemd.services.gufo = {
      description = "Gufo OpenAI-compatible inference server";
      documentation = [ "https://github.com/gufo-org/gufo/blob/main/docs/SERVER.md" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = cfg.environment;

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/gufo ${lib.escapeShellArgs serveArgs}";
        User = cfg.user;
        Group = "users";
        # /dev/kfd and /dev/dri/renderD* are gated by these groups.
        SupplementaryGroups = [
          "render"
          "video"
        ];
        WorkingDirectory = "/var/lib/gufo";
        StateDirectory = "gufo";
        # Flash-Next pins host buffers for its checkpoint/KV pages; without an
        # unlimited memlock the kernel refuses the pins and the engine falls
        # back to ordinary registration.
        LimitMEMLOCK = "infinity";
        # Model load is tens of seconds on first touch of ~104 GiB of weights.
        TimeoutStartSec = 600;
        Restart = "on-failure";
        RestartSec = 10;
        # A GPU reset/hang wedges the process for good; the supervisor's job is
        # to bring it back, not to keep the wedged process alive.
        StartLimitIntervalSec = 0;
        KillSignal = "SIGTERM";
        TimeoutStopSec = 60;
      };
    };
  };
}
