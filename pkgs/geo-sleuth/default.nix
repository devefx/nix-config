{
  lib,
  stdenv,
  fetchFromGitHub,
}:

# geo-sleuth (https://github.com/Oldcircle/geo-sleuth) is a standard Agent
# Skill: one folder holding `SKILL.md`, `scripts/`, `references/` and `data/`.
# Only the skill folder is packaged here — the scripts declare their own
# dependencies in PEP 723 headers and are meant to be run through `uv run`,
# which resolves torch / transformers / playwright / opencv from PyPI on first
# use. Vendoring that closure would duplicate upstream's own pinning for a
# multi-GB ML stack, so `uv` is this package's runtime contract; see
# `modules.aiAgents.geoSleuth` in home/base/gui/ai-agents.nix.
#
# The whole `skills/geo-sleuth` tree is kept. `scripts/*.py` import each other
# (`_net`, `_browser`, `_image`, `regions`, `osm`, ...), and `data/` plus the
# region packs are read through paths relative to the skill directory, so
# trimming any part of it breaks the skill.
#
# `scripts/refresh.py` rewrites `data/` in place. It is an upstream maintainer
# tool, not something a session runs, and it fails against the read-only store
# path by design — refresh the tables by bumping `rev` instead.
stdenv.mkDerivation (finalAttrs: {
  pname = "geo-sleuth";
  version = "0-unstable-2026-10-29";

  src = fetchFromGitHub {
    owner = "Oldcircle";
    repo = "geo-sleuth";
    rev = "bb5c2400af8cd6f05849d0c5f3346980c0b16d15";
    hash = "sha256-OC0jfTYjrpWGCD4YXhZl+wbHKzwFGD61geDmLU5SnEA=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -a "skills/geo-sleuth" "$out/share/geo-sleuth"
    runHook postInstall
  '';

  meta = {
    description = "Agent skill that geolocates a photo from OSM geometry, DEM skylines and street view";
    homepage = "https://github.com/Oldcircle/geo-sleuth";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
})
