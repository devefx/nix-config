{
  lib,
  stdenv,
  fetchurl,
  unzip,
  curl,
}:
# FelixDict (https://github.com/AndreGeng/FelixDict) — word lookup, prefix
# suggestions and translation inside the Vicinae launcher.
#
# Upstream publishes a prebuilt per-release bundle (`FelixDict-Vicinae-<v>.zip`)
# that needs no npm build, but the extension is not in the Vicinae store yet, so
# it is fetched and laid out here in the shape `programs.vicinae.extensions`
# expects. That option names the target directory after the derivation's store
# name, and Vicinae keys an extension's preferences and query cache on that
# directory name, so the store name has to stay `felixdict-vicinae` — `name` is
# therefore set explicitly instead of letting pname+version append a suffix.
#
# Every HTTP query shells out to a hardcoded `/usr/bin/curl` (upstream prefers
# curl over Node's fetch for its TLS/proxy behaviour, and only tested macOS and
# Arch). NixOS has no `/usr/bin/curl`, so the path is rewritten to the store
# path. Speech needs nothing here: on Linux the extension already spawns
# `spd-say` from PATH.
stdenv.mkDerivation (finalAttrs: {
  name = "felixdict-vicinae";
  version = "0.2.1";

  src = fetchurl {
    url = "https://github.com/AndreGeng/FelixDict/releases/download/v${finalAttrs.version}/FelixDict-Vicinae-${finalAttrs.version}.zip";
    hash = "sha256-Pnr+nFhAnBBT9h3zrKjg3H/itmP7JuWYA1Q6QeQNoDw=";
  };

  nativeBuildInputs = [ unzip ];

  postPatch = ''
    # The archive's only top-level directory is the extension itself, so stdenv
    # makes it the source root and the bundle sits at `./` here.
    substituteInPlace search.js \
      --replace-fail '"/usr/bin/curl"' '"${lib.getExe curl}"'
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a ./. "$out"/
    runHook postInstall
  '';

  meta = {
    description = "FelixDict dictionary and translation extension for Vicinae";
    homepage = "https://github.com/AndreGeng/FelixDict";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
