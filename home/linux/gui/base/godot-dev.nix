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
# CPATH / LIBRARY_PATH / PKG_CONFIG_PATH are injected to let scons
# find them. Run e.g.: `scons platform=linuxbsd target=editor`.
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
      ]
      ++ devLibs;

    # Stable home-directory lib bundle for tools that do not inherit the
    # login session (e.g. VSCode's debug adapter) but still need to launch
    # Godot with LD_LIBRARY_PATH.
    home.file.".config/godot-dev/lib".source = "${godotRunLibs}/lib";

    # Some terminal setups skip /etc/profile (e.g. interactive non-login
    # shells), so also make the runtime lib path available in ~/.bashrc.
    home.activation.godotLdLibraryPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      bashrc="${config.home.homeDirectory}/.bashrc"
      touch "$bashrc"
      if ! grep -q 'godot-dev/lib' "$bashrc"; then
        printf '\n# Godot dev runtime libraries\nexport LD_LIBRARY_PATH="%s/.config/godot-dev/lib''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH"\n' "${config.home.homeDirectory}" >> "$bashrc"
      fi
    '';

    # Point the toolchain at nix-store include/lib paths.
    home.sessionVariables = {
      CPATH = concatStringsSep ":" (map (p: "${p}/include") devLibs);
      LIBRARY_PATH = concatStringsSep ":" (map (p: "${p}/lib") devLibs);
      LD_LIBRARY_PATH = lib.makeLibraryPath runLibs;
      PKG_CONFIG_PATH = concatStringsSep ":" (map (p: "${p}/lib/pkgconfig") devLibs);
    };
  };
}
