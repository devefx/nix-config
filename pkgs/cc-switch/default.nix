{
  cc-switch,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_10,
  sqlite,
}:
# nixpkgs' cc-switch has been stuck on 3.16.5 (schema v11) since 2026-07;
# upstream is on 3.20.x (schema v19). Only the version and the fetched-input
# hashes differ, so reuse the nixpkgs recipe through `overrideAttrs` instead of
# forking it. 3.20.x migrates an existing v11 database forward in place, so the
# reset note that used to live in the home module no longer applies.
#
# NOTE: the migration is one-way. Once 3.20.4 has upgraded the database to v19,
# reverting to nixpkgs' 3.16.5 fails at startup with "数据库版本过新": schema.rs
# rejects any `user_version > SCHEMA_VERSION`. Back up ~/.cc-switch/cc-switch.db
# before the first launch.
cc-switch.overrideAttrs (
  finalAttrs: old: {
    version = "4.0.31";

    src = fetchFromGitHub {
      owner = "farion1231";
      repo = "cc-switch";
      tag = "v${finalAttrs.version}";
      hash = "sha256-up9/Q8qa4TirhxHT9fU0GoJ9x8BZX9TP9rgH7qNrvlM=";
    };

    pnpmDeps = fetchPnpmDeps {
      pname = "cc-switch";
      version = finalAttrs.version;
      src = finalAttrs.src;
      pnpm = pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-1VFkWR1fxeu2J1gKApl0j5AP0fo6lNdiXCe+ry9yPGI=";
    };

    cargoHash = "sha256-fwkQBcIHzgpa5V4GzyRo9m7D156H3hWGhZSM3pV2LxI=";

    # nixpkgs' 3.16.5 has no sqlite in `buildInputs` (its Cargo.lock bundled
    # SQLite); 4.0.20 links the system one, so the link fails with
    # `cannot find -lsqlite3` unless it is provided.
    buildInputs = old.buildInputs ++ [ sqlite ];

    # buildRustPackage derives the vendored-deps derivation from its original
    # argument set, so overriding `cargoHash` alone leaves the old hash on the
    # staging fixed-output derivation that actually does the fetching.
    cargoDeps = old.cargoDeps.overrideAttrs (vendor: {
      vendorStaging = vendor.vendorStaging.overrideAttrs (_: {
        outputHash = "sha256-fwkQBcIHzgpa5V4GzyRo9m7D156H3hWGhZSM3pV2LxI=";
      });
    });

    # Upstream tests that hardcode an FHS layout (`/bin/echo`, a `bash` or `npm`
    # shim on PATH) and cannot pass inside the Nix sandbox; the remaining ~4000
    # pass. 4.0.20 added the two `anchored_upgrade`/`unix_launcher` cases below.
    checkFlags = [
      "--skip=commands::misc::tests::anchored_upgrade::npm_anchor_supplies_sibling_node_to_env_shebang"
      "--skip=commands::misc::tests::anchored_upgrade::claude_updater_child_inherits_scoped_settings_without_parent_leakage"
      "--skip=commands::misc::tests::probe_version_command_captures_healthy_tool_output"
      "--skip=commands::misc::tests::unix_launcher_script_passes_env_past_rc_files_and_cleans_up"
      "--skip=session_manager::providers::mcode::tests::mcode_history_uses_visible_roots_and_display_messages"
      # 4.0.31's MCP connectivity tests spawn a login shell, which does not
      # exist in the Nix build sandbox (Os { code: 2, kind: NotFound }).
      "--skip=services::mcp_connectivity::tests::stdio_keeps_inherited_path_when_login_shell_resolution_fails"
      "--skip=services::mcp_connectivity::tests::stdio_login_path_finds_bare_launchers_and_configured_path_wins"
    ];
  }
)
