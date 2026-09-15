{
  lib,
  pkgs,
  config,
  ...
}:
# Godot engine development environment — for building the engine itself
# from source, not for making games with the editor (see godot.nix for
# the prebuilt editor). Follows the official Linux/BSD compile guide:
# https://docs.godotengine.org/zh-cn/4.x/engine_details/development/compiling/compiling_for_linuxbsd.html
#
# Provides:
#   - scons / python3 — build system + build scripts
#   - gcc / clang     — compilers (scons defaults to g++)
#   - pkg-config      — scons resolves most dev libs via pkg-config
#   - X11 / Wayland / ALSA / PulseAudio / udev / systemd dev headers
#   - OpenGL (mesa) + Vulkan (headers / glslang) tooling
#
# On NixOS headers live in the nix store, not /usr/include, so
# `godot-dev-env` injects CPATH / LIBRARY_PATH / PKG_CONFIG_PATH for scons.
# Run e.g.: `godot-dev-env scons platform=linuxbsd target=editor`.
#
# Gated behind `modules.godotDev.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf concatStringsSep;

  cfg = config.modules.godotDev;

  # clang's wrapper ships the same generic compiler names as gcc's wrapper
  # (cc/c++/cpp plus binutils symlinks), so home-manager's buildEnv cannot
  # merge both into the same PATH. Keep only clang/clang++ and let gcc win
  # the generic names.
  clangNoCxx = pkgs.symlinkJoin {
    name = "clang-no-cxx";
    paths = [ pkgs.clang ];
    postBuild = ''
      for tool in addr2line ar as c++ c++filt cc cpp dwp elfedit gprof ld \
        ld.bfd ld.gold nm objcopy objdump ranlib readelf size strings strip; do
        rm -f "$out/bin/$tool"
      done
    '';
  };

  # dev outputs of the libraries the engine links against
  devLibs = with pkgs; [
    libx11.dev # X11
    libxcursor.dev
    libxinerama.dev
    libxi.dev
    libxrandr.dev
    wayland.dev # Wayland
    libxkbcommon.dev
    mesa # OpenGL headers + gl.pc (single output)
    libGL # OpenGL runtime lib (libglvnd)
    alsa-lib.dev # audio
    libpulseaudio.dev
    libudev-zero # device hotplug (--use-udev), single-output package
    systemd.dev
    vulkan-headers # Vulkan headers
  ];

  # Godot loads these at runtime with dlopen (use_sowrap default), so their
  # runtime outputs must be on LD_LIBRARY_PATH on NixOS.
  runLibs = with pkgs; [
    alsa-lib
    dbus
    fontconfig
    freetype
    libGL
    libdecor
    libpulseaudio
    libudev-zero
    libx11
    libxcursor
    libxext
    libxfixes
    libxi
    libxinerama
    libxkbcommon
    libxrandr
    libxrender
    mesa
    speechd
    vulkan-loader
    wayland
  ];

  godotRunLibs = pkgs.buildEnv {
    name = "godot-run-libs";
    paths = map lib.getLib runLibs;
    pathsToLink = [ "/lib" ];
    ignoreCollisions = true;
  };

  toolchainEnv = {
    CPATH = concatStringsSep ":" (map (p: "${p}/include") devLibs);
    LIBRARY_PATH = concatStringsSep ":" (map (p: "${p}/lib") devLibs);
    PKG_CONFIG_PATH = concatStringsSep ":" (map (p: "${p}/lib/pkgconfig") devLibs);
  };

  # Scope the build and runtime environment to these wrappers instead of
  # polluting every process in the desktop session.
  godotDevEnv = pkgs.writeShellScriptBin "godot-dev-env" ''
    export CPATH="${toolchainEnv.CPATH}"
    export LIBRARY_PATH="${toolchainEnv.LIBRARY_PATH}"
    export PKG_CONFIG_PATH="${toolchainEnv.PKG_CONFIG_PATH}"
    export LD_LIBRARY_PATH="${godotRunLibs}/lib"
    exec "$@"
  '';

  # VSCode launch configs can use this as the program and pass the real Godot
  # binary in args.
  godotDevRun = pkgs.writeShellScriptBin "godot-dev-run" ''
    export LD_LIBRARY_PATH="${godotRunLibs}/lib"
    exec "$@"
  '';
in
{
  options.modules.godotDev = {
    enable = mkEnableOption "Godot engine dev environment (build the engine from source)";
  };

  config = mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        scons # build system used by Godot
        python3 # required by the SConstruct scripts
        pkg-config # scons resolves dev libs via pkg-config
        gcc # default compiler
        clangNoCxx # alternative compiler (generic cc/c++ names belong to gcc)
        lld # LLVM linker, for `scons use_llvm=yes linker=lld`
        glslang # shader compiler (Vulkan)
        vulkan-loader # Vulkan runtime
        wayland-scanner # generates Wayland protocol bindings
        godotDevEnv
        godotDevRun
      ]
      ++ devLibs;

    # Remove the old global path injected by previous generations. Keeping
    # libudev from Godot's runtime bundle on the global search path breaks
    # unrelated desktop tools such as NetworkManager's nmcli.
    home.activation.removeGodotLdLibraryPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      bashrc="${config.home.homeDirectory}/.bashrc"
      if [ -f "$bashrc" ] && grep -q '^# Godot dev runtime libraries$' "$bashrc"; then
        sed -i '/^# Godot dev runtime libraries$/,+1d' "$bashrc"
      fi
    '';
  };
}
