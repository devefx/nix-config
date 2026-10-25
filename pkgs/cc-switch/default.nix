{
  cc-switch,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_10,
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
    version = "4.0.20";

    src = fetchFromGitHub {
      owner = "farion1231";
      repo = "cc-switch";
      tag = "v${finalAttrs.version}";
      hash = "sha256-tHamU9GQxfo+2QvczRFV8qO5ZrQzxiFX3yd3+JKXDQg=";
    };

    pnpmDeps = fetchPnpmDeps {
      pname = "cc-switch";
      version = finalAttrs.version;
      src = finalAttrs.src;
      pnpm = pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-+BKQY+QFdoo+gi5ObGDS0vd6KwG7jsRZIEF7/8/K89Q=";
    };

    cargoHash = "sha256-ZHndpX18+khp18/KyFSwKGn3uioFOIyAfagjeXC+T30=";

    # buildRustPackage derives the vendored-deps derivation from its original
    # argument set, so overriding `cargoHash` alone leaves the old hash on the
    # staging fixed-output derivation that actually does the fetching.
    cargoDeps = old.cargoDeps.overrideAttrs (vendor: {
      vendorStaging = vendor.vendorStaging.overrideAttrs (_: {
        outputHash = "sha256-ZHndpX18+khp18/KyFSwKGn3uioFOIyAfagjeXC+T30=";
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
    ];
  }
)
