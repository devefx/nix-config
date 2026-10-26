{
  lib,
  stdenv,
  fetchurl,
  id,
  version,
  hash,
}:
# A single pinned Joplin plugin. The published `.jpl` bundle is fetched as-is
# and placed in `$out/<id>.jpl`; Joplin loads whatever `*.jpl` files it finds
# in its plugin directory, so no extraction or rebuild is involved.
#
# Nixpkgs' own `joplin-desktop` derivation uses the same output shape for the
# plugins it bundles (`install -Dm444 -t $out publish/*.jpl`).
stdenv.mkDerivation {
  pname = id;
  inherit version;

  src = fetchurl {
    # Marketplace download link, see registry.nix. `@` is not a legal store
    # path character, so the download name is overridden.
    url = "https://github.com/joplin/plugins/releases/download/plugins/${id}@${version}.jpl";
    name = "${id}-${version}.jpl";
    inherit hash;
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm444 "$src" "$out/${id}.jpl"
    runHook postInstall
  '';

  meta = {
    description = "Joplin plugin ${id}";
    homepage = "https://joplinapp.org/plugins/plugin/${id}";
    license = lib.licenses.mit;
  };
}
