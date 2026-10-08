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
    version = "3.20.4";

    src = fetchFromGitHub {
      owner = "farion1231";
      repo = "cc-switch";
      tag = "v${finalAttrs.version}";
      hash = "sha256-UewKhov4j+qa+319rMFUd+/80ylzPuleC79pEdaBJKI=";
    };

    pnpmDeps = fetchPnpmDeps {
      pname = "cc-switch";
      version = finalAttrs.version;
      src = finalAttrs.src;
      pnpm = pnpm_10;
      fetcherVersion = 3;
      hash = "sha256-uqY6/WSVsuvfcJsbWMYenaxLp9gDguiMAyb/mepv028=";
    };

    cargoHash = "sha256-DdvQ084Aop+rr6ECc5+lEJ4gSxDTtl6sF+ixjj6Dg6Q=";

    # buildRustPackage derives the vendored-deps derivation from its original
    # argument set, so overriding `cargoHash` alone leaves the old hash on the
    # staging fixed-output derivation that actually does the fetching.
    cargoDeps = old.cargoDeps.overrideAttrs (vendor: {
      vendorStaging = vendor.vendorStaging.overrideAttrs (_: {
        outputHash = "sha256-DdvQ084Aop+rr6ECc5+lEJ4gSxDTtl6sF+ixjj6Dg6Q=";
      });
    });

    # Three upstream tests hardcode an FHS layout (`/bin/echo`, an `npm` shim on
    # PATH) and cannot pass inside the Nix sandbox; the remaining ~2900 pass.
    checkFlags = [
      "--skip=commands::misc::tests::anchored_upgrade::npm_anchor_supplies_sibling_node_to_env_shebang"
      "--skip=commands::misc::tests::probe_version_command_captures_healthy_tool_output"
      "--skip=session_manager::providers::mcode::tests::mcode_history_uses_visible_roots_and_display_messages"
    ];
  }
)
