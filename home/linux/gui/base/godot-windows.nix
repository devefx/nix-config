{
  lib,
  pkgs,
  config,
  ...
}:
# Windows export templates cross-compiled on NixOS with mingw-w64.
#
# nixpkgs's mingw-w64 GCC uses mcfgthread instead of winpthreads, so scons
# needs both the mcfgthread dev headers and its import library. The wrapper
# also omits `gcc-ar`/`gcc-ranlib`, which Godot's SConstruct expects; add the
# two symlinks in a merged bin dir.
#
# Usage:
#   cd /mnt/data/Shared/github/workspace/godot
#   godot-windows-build target=template_release arch=x86_64
#   godot-windows-build target=template_debug arch=x86_64
#
# D3D12 support needs Godot's dependencies downloaded once:
#   cd /mnt/data/Shared/github/workspace/godot
#   python3 misc/scripts/install_d3d12_sdk_windows.py
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.godotWindows;

  mingw = pkgs.pkgsCross.mingwW64;
  crossGcc = mingw.stdenv.cc;
  mcfgthread = mingw.windows.mcfgthreads;
  mcfgthreadDev = mcfgthread.dev;
  mcfgthreadLib = mcfgthread;

  # mingw-w64 wrapper bin plus the gcc-ar/gcc-ranlib names Godot looks for.
  mingwTools = pkgs.symlinkJoin {
    name = "mingw-w64-tools";
    paths = [ crossGcc ];
    postBuild = ''
      ln -s ${crossGcc}/bin/x86_64-w64-mingw32-ar $out/bin/x86_64-w64-mingw32-gcc-ar
      ln -s ${crossGcc}/bin/x86_64-w64-mingw32-ranlib $out/bin/x86_64-w64-mingw32-gcc-ranlib
    '';
  };

  godotWindowsBuild = pkgs.writeShellScriptBin "godot-windows-build" ''
    set -euo pipefail

    source_dir="''${GODOT_SOURCE_DIR:-$PWD}"
    if [[ ! -f "$source_dir/SConstruct" ]]; then
      echo "godot-windows-build: Godot source not found. Run from the source root or set GODOT_SOURCE_DIR." >&2
      exit 1
    fi
    cd "$source_dir"

    export PATH="${mingwTools}/bin:$PATH"
    exec scons platform=windows use_mingw=yes \
      ccflags="-I${mcfgthreadDev}/include" \
      linkflags="-L${mcfgthreadLib}/lib -lmcfgthread" \
      "$@"
  '';
in
{
  options.modules.godotWindows = {
    enable = mkEnableOption "Godot Windows export template cross-compile environment";
  };

  config = mkIf cfg.enable {
    home.packages = [
      mingwTools
      godotWindowsBuild
    ];
  };
}
