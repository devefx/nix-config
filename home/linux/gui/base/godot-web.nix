{
  lib,
  pkgs,
  config,
  ...
}:
# Web export templates cross-compiled on NixOS with Emscripten.
#
# nixpkgs's `emscripten` provides emcc/em++/emar/emranlib and references Node
# internally, but Godot's SCons web build also calls `zip` from PATH. The
# wrapper keeps emcc, node and zip available and gives Emscripten a stable,
# writable cache under ~/.cache.
#
# Usage:
#   cd /mnt/data/Shared/github/workspace/godot
#   godot-web-build target=template_release
#   godot-web-build target=template_debug
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.godotWeb;

  emscripten = pkgs.emscripten;
  cacheDir = "${config.home.homeDirectory}/.cache/emscripten-${emscripten.version}";

  godotWebBuild = pkgs.writeShellScriptBin "godot-web-build" ''
    set -euo pipefail

    source_dir="''${GODOT_SOURCE_DIR:-$PWD}"
    if [[ ! -f "$source_dir/SConstruct" ]]; then
      echo "godot-web-build: Godot source not found. Run from the source root or set GODOT_SOURCE_DIR." >&2
      exit 1
    fi
    cd "$source_dir"

    export PATH="${emscripten}/bin:${pkgs.zip}/bin:${pkgs.nodejs}/bin:$PATH"
    export EM_CACHE="''${EM_CACHE:-${cacheDir}}"
    mkdir -p "$EM_CACHE"

    exec scons platform=web "$@"
  '';
in
{
  options.modules.godotWeb = {
    enable = mkEnableOption "Godot Web export template build environment (Emscripten)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      emscripten
      pkgs.zip
      pkgs.nodejs
      godotWebBuild
    ];
  };
}
