{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_24,
}:

# `pi-web` is the community Web UI for the Pi coding agent
# (https://github.com/agegr/pi-web). It is NOT a Pi extension: it is a
# standalone Next.js application that talks to the Pi SDK in-process and
# shows the same sessions, providers and project files the `pi` CLI uses.
#
# The published npm tarball already contains a finished `next build` output
# (664 files under `.next/`), so there is no build step here. `dontNpmBuild`
# skips the upstream `build` script, and the devDependency set (playwright,
# mermaid, katex, typescript, tailwind) never enters the closure.
#
# The tarball ships no `node_modules` and no lockfile. `next.config.ts`
# declares `serverExternalPackages` for node-pty, undici, web-push and the
# four `@earendil-works/*` Pi packages, which means exactly those stay
# external at runtime; everything else is already bundled into
# `.next/server/chunks`. The committed `package-lock.json` beside this file
# supplies the missing lockfile so Nix can fetch a complete, reproducible
# dependency closure.
#
# Note the Pi packages installed here are the versions pi-web pins, which is
# deliberately independent of the `pi` CLI this repository takes from the
# llm-agents flake input. The two do not conflict: pi-web resolves its own
# copies from its own `node_modules`.

buildNpmPackage (finalAttrs: {
  pname = "pi-web";
  version = "0.12.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@agegr/pi-web/-/pi-web-${finalAttrs.version}.tgz";
    hash = "sha256-7ZfPJ7sZISyBqdWHMEbMnLKaihH4STxN+enPZ7ERZYk=";
  };

  # The published tarball carries no lockfile, and its package.json still
  # lists the full devDependency set (playwright, mermaid, katex, tailwind,
  # typescript). `npm ci` would try to resolve those out of the cache and die
  # with ENOTCACHED, so drop the block before installing. The committed
  # `package-lock.json` beside this file was generated from the published
  # `dependencies` block alone with
  # `npm install --package-lock-only --ignore-scripts`, which yields 188
  # entries and no devDependencies at all.
  #
  # `postPatch` runs in both derivations buildNpmPackage creates: the
  # `-npm-deps` one that prefetches the cache from the lockfile, and the main
  # build. Only the latter has `nodejs` on PATH -- the npm-deps derivation
  # carries just `prefetch-npm-deps` and stdenv -- so the JSON edit is guarded
  # on `node` being available. It is only needed for the main build anyway:
  # prefetch-npm-deps reads the lockfile and never consults package.json.
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

  npmDepsHash = "sha256-KBaaxduTtFWrJCd0Igvxjok6jnP+EIAlhpgkyZAI4nQ=";

  # The tarball is already built; `dontNpmBuild` makes the default
  # `npm run build` a no-op. Lifecycle scripts stay off: the only
  # postinstall (`bin/prepare-terminal.js`) fixes macOS-only spawn-helper
  # permission bits, and node-pty's install script would try to download or
  # compile a prebuild even though the tarball already carries
  # `prebuilds/linux-x64/pty.node`.
  dontNpmBuild = true;
  npmRebuildFlags = [ "--ignore-scripts" ];

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  # `create-node-module` calls `npm ci`, which runs lifecycle scripts unless
  # they are disabled through the environment. node-pty's `install` script
  # would otherwise shell out to `node-gyp rebuild` and fail in the sandbox;
  # its shipped linux-x64 prebuild is what we want.
  env = {
    npm_config_ignore_scripts = "true";
    NEXT_TELEMETRY_DISABLED = "1";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/pi-web"
    cp -a bin .next public package.json next.config.ts LICENSE "$out/libexec/pi-web/"

    mkdir -p "$out/libexec/pi-web/node_modules"
    cp -a node_modules/. "$out/libexec/pi-web/node_modules/"

    # The published tarball bakes its preview-mode secrets into
    # `.next/prerender-manifest.json`. `previewModeId` is compared against the
    # `x-prerender-revalidate` request header, and a match makes Next treat the
    # request as an on-demand revalidation and skip middleware entirely — which
    # bypasses pi-web's password gate and its Host/Origin checks. The value is
    # identical in every published copy, so anyone who unpacks the npm tarball
    # knows it.
    #
    # pi-web fixes this at startup by rewriting the values with fresh random
    # ones, but that needs a writable install directory. The Nix store is
    # read-only, so the rotation fails, the launcher warns, and it then serves
    # with the compromised id. Rotating here instead restores the property that
    # matters: the on-disk id must not be the published one.
    node ${./rotate-preview-secrets.cjs} "$out/libexec/pi-web/.next"

    # `bin/pi-web.js` resolves the Next CLI relative to its own package root,
    # so the wrapper must exec the script inside the installed tree.
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/pi-web" \
      --add-flags "$out/libexec/pi-web/bin/pi-web.js"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/pi-web" version
    runHook postInstallCheck
  '';

  meta = {
    description = "Web UI for the Pi coding agent";
    homepage = "https://github.com/agegr/pi-web";
    license = lib.licenses.mit;
    mainProgram = "pi-web";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
