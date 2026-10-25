{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_24,
}:

# REA (Reverse Engineer Anything, https://github.com/morluto/rea) is a CLI and
# MCP server for binary / application reverse engineering.
#
# Upstream's supported install path is `npx -y rea-agents@<version> mcp`, which
# resolves and downloads the package at *client startup*: the first session
# after a boot would block on a network fetch, and every session would silently
# follow whatever the registry serves for that version. Packaging it keeps the
# MCP server hermetic and version-pinned.
#
# The published tarball is already built (`dist/` is the bundled JS; the
# `bridge/` Python and Ghidra Java sources ship as data). There is no build
# step: `dontNpmBuild` skips upstream's `build` script, which needs turbo and
# the full devDependency set.
#
# `package.json` lists 23 devDependencies (vitest, turbo, typescript, oxlint,
# oxfmt, ...) that only exist for upstream's own checks. `npm ci` resolves the
# whole graph before running anything, so they have to go before the install;
# the committed `package-lock.json` beside this file was regenerated from the
# published `dependencies` block alone with
# `npm install --package-lock-only --ignore-scripts`, yielding 178 entries and
# no devDependencies.
#
# Node comes from nixpkgs rather than upstream's recommended build: the
# `evmole` dependency ships a prebuilt native addon, and REA's own
# `engines.node` (`^22.19.0 || ^24.11.0 || >=26.0.0`) is satisfied either way,
# so the Node version this repository already uses for the other agents is
# enough and keeps the native `.node` addons on one ABI.
buildNpmPackage (finalAttrs: {
  pname = "rea-agents";
  version = "6.7.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/rea-agents/-/rea-agents-${finalAttrs.version}.tgz";
    hash = "sha256-IJWKZtuhoBHlCkhr65Rjo0MSjtNoyYT5QGU2LBP1H5A=";
  };

  # Upstream's `package.json` carries `scripts.prepare` and `scripts.prepack`,
  # which `npm ci` would run. Both are upstream build tooling (they shell out to
  # turbo / tsc); the tarball is already built, so they are dropped along with
  # the devDependencies. `npm ci --ignore-scripts` is used by the hook anyway,
  # but the JSON edit keeps `npm` from failing on unresolvable script targets.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json

    if command -v node >/dev/null 2>&1; then
      node -e '
        const fs = require("fs");
        const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
        delete pkg.devDependencies;
        delete pkg.scripts;
        fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
      '
    fi
  '';

  npmDepsHash = "sha256-osmsWiATYCazHi2RL3ptkyV/CpRTzlpVprVcL3lvE2M=";

  dontNpmBuild = true;
  npmRebuildFlags = [ "--ignore-scripts" ];

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  env = {
    npm_config_ignore_scripts = "true";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/rea-agents"
    cp -a dist scripts skills bridge native third_party licenses \
      package.json README.md DISCLAIMER.md THIRD_PARTY_NOTICES.md LICENSE \
      "$out/libexec/rea-agents/"

    # The whole dependency tree is needed at runtime; `dist/` is bundled but
    # still imports the `dependencies` (zod, yaml, @lydell/node-pty, evmole,
    # playwright-core, ...) by name.
    mkdir -p "$out/libexec/rea-agents/node_modules"
    cp -a node_modules/. "$out/libexec/rea-agents/node_modules/"

    makeWrapper ${lib.getExe nodejs_24} "$out/bin/rea" \
      --add-flags "$out/libexec/rea-agents/scripts/rea.mjs"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/rea-agents" \
      --add-flags "$out/libexec/rea-agents/scripts/rea.mjs"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/rea" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI and MCP server for reverse engineering binaries, applications and runtimes";
    homepage = "https://github.com/morluto/rea";
    license = lib.licenses.mit;
    mainProgram = "rea";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
