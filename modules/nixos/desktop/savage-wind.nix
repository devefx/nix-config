{
  config,
  lib,
  pkgs,
  myvars ? { },
  ...
}:
# Savage Wind Recomp — the static recompilation of Breath of the Wild.
#
# Everything comes from URLs: `savage-wind-provision` (a systemd oneshot)
# downloads the base game, the 1.9.0 update and your console keys, extracts the
# ExeFS, merges the update's BKTR section into the base RomFS, splits the result
# into a file tree, and recompiles the game code on this machine. A fresh
# install then needs nothing but the network and this configuration.
#
# Upstream expects `exefs/` and `romfs/` that the player extracted themselves —
# it "never decrypts anything". The extractors in pkgs/savage-wind-extract are
# MacNativeGames' (MIT), patched to take the title id as an option, and hactool
# is patched for the BKTR layout cumulative updates use (pkgs/hactool-bktr).
#
# The game lands in a writable folder rather than a store path: it writes
# `savagewind.ini`, shader caches and saves next to its own data. Only the
# saves and settings are pulled out into `stateDir`, so a rebuild of the game
# code keeps them.
#
# Gyro aiming needs the controller's raw HID reports from /dev/hidraw*, and
# reads there are shared: Steam's Steam Input takes the same reports, so with
# it on the game logs "SDL motion timeout" and falls back to nothing. Buttons
# and sticks keep working, because those come through the kernel's
# hid-nintendo driver on evdev, which nothing competes for. Disable Steam
# Input for this game (Steam: Properties > Controller) to get gyro back; a
# Cemuhook DSU server is the other route, but it reads hidraw too, so it does
# not help while Steam Input is on. `SAVAGEWIND_MOTION_LOG=1` prints the
# sensor stream's health once a second.
let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    makeLibraryPath
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.modules.desktop.savage-wind;

  hactoolBktr = pkgs.callPackage ../../../pkgs/hactool-bktr { };
  swExtract = pkgs.callPackage ../../../pkgs/savage-wind-extract {
    hactool = hactoolBktr;
  };

  # The release is an AppImage. Rather than mounting it with FUSE, the
  # derivation unpacks its squashfs, points the interpreter at the nix glibc and
  # keeps the bundled `usr/lib` next to `usr/bin` — the binary's own RUNPATH is
  # `$ORIGIN/../lib`, which is where SDL3, FFmpeg and shaderc live.
  release =
    pkgs.runCommand "savagewind-${cfg.version}"
      {
        nativeBuildInputs = [
          pkgs.squashfs-tools
          pkgs.patchelf
        ];
      }
      ''
        cp ${pkgs.fetchurl { inherit (cfg.appImage) url hash; }} release.AppImage
        chmod +x release.AppImage
        offset=$(./release.AppImage --appimage-offset)
        unsquashfs -q -o "$offset" -d rootfs release.AppImage >/dev/null

        # `zig` is statically linked and has no .interp to rewrite.
        for f in rootfs/usr/bin/savagewind rootfs/usr/bin/swgen/swgen rootfs/usr/bin/zig/zig; do
          [ -f "$f" ] || continue
          patchelf --print-interpreter "$f" >/dev/null 2>&1 || continue
          old=$(patchelf --print-rpath "$f" 2>/dev/null || true)
          patchelf \
            --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
            --set-rpath "''${old:+$old:}${runtimeLibs}" \
            "$f"
        done

        mkdir -p $out
        cp -r rootfs/usr $out/
      '';

  # Everything the release does not bundle. SDL3 pulls in the X11 and Wayland
  # libraries it was built against; without libXtst/libXss it aborts in
  # `ui_window_init`, and its audio backends are dlopen'd — ALSA, PipeWire and
  # PulseAudio in that order — so a missing libasound just leaves the game
  # silent ("SDL audio init failed: Failed loading libasound.so.2").
  runtimeLibs = makeLibraryPath (
    with pkgs;
    [
      glibc
      zlib
      gcc.cc.lib
      vulkan-loader
      alsa-lib
      libpulseaudio
      pipewire
      # SDL3 dlopen's libudev to enumerate the input devices; without it the
      # joystick list comes back empty even though the pad is in /dev/input.
      udev
      libx11
      libxext
      libxcursor
      libxi
      libxfixes
      libxrandr
      libxscrnsaver
      libxtst
      libxkbcommon
      wayland
      libdecor
    ]
  );

  gameDir = "${cfg.stateDir}/extracted";

  # The in-game menu writes back to the file `SAVAGEWIND_SETTINGS` names, so it
  # cannot live in the store. A copy is placed in `stateDir` on first boot and
  # the game edits that; `C` in tmpfiles never overwrites an existing file, so
  # the player's changes survive a rebuild.
  settingsFile = pkgs.writeText "savagewind.ini" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "${name} = ${toString value}") cfg.ini)
    + "\n"
  );

  # Reads the two game-code ids out of the binary: gamelib_id() returns
  # GAMELIB_ID_COMPAT for CPUs without AVX2 and GAMELIB_ID otherwise, and both
  # are 16-hex strings in .rodata that a pair of `lea` instructions loads.
  # Verified against `gdb -ex 'p gamelib_id()'` on 0.4.1-alpha.4.
  gameLibIdScript = pkgs.writeShellApplication {
    name = "savagewind-gamelib-id";
    runtimeInputs = [
      pkgs.binutils
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.xxd
    ];
    text = ''
      bin=$1
      dis=$(objdump -d --disassemble=gamelib_id "$bin")
      addr_cx=$(printf '%s\n' "$dis" | awk '/lea .*%rip\),%rcx/{print; exit}' | grep -oP '# \K[0-9a-f]+')
      addr_ax=$(printf '%s\n' "$dis" | awk '/lea .*%rip\),%rax/{print; exit}' | grep -oP '# \K[0-9a-f]+')
      read_at() {
        objdump -s --start-address=$((16#$1)) --stop-address=$((16#$1 + 16)) "$bin" |
          tail -1 | awk '{for (i = 2; i <= NF; i++) printf "%s", $i}' | head -c 32 | xxd -r -p
      }
      echo "$(read_at "$addr_cx") $(read_at "$addr_ax")"
    '';
  };

  # The per-file compile driver. It lives here rather than in the provisioner
  # because xargs calls it directly and the flags are a fixed list; the paths
  # and the target CPU arrive as environment variables.
  compileDriver = pkgs.writeScript "savage-wind-compile.sh" ''
    #!/bin/sh
    set -e
    src_file=$1
    obj="$BUILD/obj/$(printf '%s' "$src_file" | tr '/' '_' | sed 's/\.c$//').o"
    exec "$ZIG" cc -target x86_64-linux-gnu.2.35 \
      -O1 -fno-strict-aliasing -Wno-return-type -Wno-unused-label -fvisibility=hidden \
      -mcpu="$MARCH" -fPIC -Xclang -O1 -fno-vectorize -fno-slp-vectorize -g0 -fomit-frame-pointer \
      -I"$SRC" -DGAMELIB_ID="\"$ID\"" -c "$src_file" -o "$obj"
  '';

  provisionScript = pkgs.writeShellApplication {
    name = "savage-wind-provision";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.curl
      pkgs.unzip
      swExtract
      gameLibIdScript
    ];
    text = ''
      set -euo pipefail

      state=${escapeShellArg cfg.stateDir}
      game=${escapeShellArg gameDir}
      work="$state/build"
      stamp="$state/.built"
      src_stamp="$state/.sources"
      want=${
        escapeShellArg (
          concatStringsSep " " [
            (toString sourceDrv.base)
            (toString sourceDrv.update)
            cfg.source.keys.hash
            (toString release)
          ]
        )
      }

      # 0. Merge the declared settings into savagewind.ini. Only the keys in
      #    `ini` are written; everything the in-game menu added stays, and the
      #    file itself is never replaced wholesale.
      ini="$state/savagewind.ini"
      mkdir -p "$state"
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        key="''${line%% = *}"
        if grep -qx "$key = .*" "$ini" 2>/dev/null; then
          sed -i "s|^$key = .*|$line|" "$ini"
        else
          printf '%s\n' "$line" >> "$ini"
        fi
      done < ${settingsFile}

      if [ -x "$game/swgame.so" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$want" ]; then
        echo "savage-wind-provision: game code already built from these sources"
      else
        if [ "$(cat "$src_stamp" 2>/dev/null || true)" != "$want" ]; then
          echo "savage-wind-provision: sources changed, discarding intermediates"
          rm -rf "$work" "$state/keys"
        fi

        mkdir -p "$work"

        # 1. Keys, into a 0700 folder. Not through `fetchurl`: the store is
        #    world-readable, and these are the console's own keys.
        keys_dir="$state/keys"
        prod_keys="$keys_dir/prod.keys"
        if [ ! -f "$prod_keys" ]; then
          echo "savage-wind-provision: fetching prod.keys"
          mkdir -p "$keys_dir"
          chmod 700 "$keys_dir"
          zip="$keys_dir/keys.zip"
          curl -fsSL -o "$zip" ${escapeShellArg cfg.source.keys.url}
          echo "${keysHashHex}  $zip" | sha256sum -c - >/dev/null
          unzip -o -q "$zip" -d "$keys_dir"
          rm -f "$zip"
          chmod 600 "$keys_dir"/*.keys 2>/dev/null || true
        fi

        # 2. ExeFS + merged RomFS + file tree.
        sw-extract \
          --base ${escapeShellArg sourceDrv.base} \
          --update ${escapeShellArg sourceDrv.update} \
          --keys "$prod_keys" \
          --hactool ${lib.getExe hactoolBktr} \
          --base-id ${escapeShellArg cfg.source.baseId} \
          --update-id ${escapeShellArg cfg.source.updateId} \
          --out "$game" \
          --work "$work/extract"

        echo "$want" > "$src_stamp"

        # 3. Recompile the game code: swgen turns exefs/main, sdk and subsdk0
        #    into C, zig builds that into swgame.so. Same steps as the start
        #    screen's "Set up game files", without the GUI.
        read -r id_avx2 id_sse < <(savagewind-gamelib-id ${release}/usr/bin/savagewind)
        if grep -qw avx2 /proc/cpuinfo; then
          gamelib_id="$id_avx2"
          march=x86_64_v3
        else
          gamelib_id="$id_sse"
          march=x86_64_v2
        fi
        echo "savage-wind-provision: game code id $gamelib_id (mcpu $march)"

        export LD_LIBRARY_PATH=${release}/usr/lib:${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
        gen=${release}/usr/bin/swgen/swgen
        zig=${release}/usr/bin/zig/zig
        src=${release}/usr/bin/gamelib-src
        build="$work/build"
        mkdir -p "$build/obj"

        echo "savage-wind-provision: reading the game code"
        "$gen" layout "$game/exefs" "$build" >/dev/null

        modules=$(awk '$1 !~ /^#/ && NF >= 4 {print $1}' "$build/layout.txt")
        for name in $modules; do
          args=("$name" "$game/exefs/$name" "$build/layout.txt" "$build/$name")
          [ "$name" = main ] || args+=(--hle "$src/hle_symbols.txt")
          echo "savage-wind-provision: generating $name"
          "$gen" "''${args[@]}" >/dev/null &
        done
        wait

        export ZIG="$zig" SRC="$src" ID="$gamelib_id" MARCH="$march" BUILD="$build"

        echo "savage-wind-provision: compiling"
        {
          echo "$build/layout.c"
          echo "$src/gamelib_entry.c"
          for name in $modules; do find "$build/$name" -name '*.c'; done
        } | xargs -P "$(nproc)" -n 1 ${compileDriver}

        echo "savage-wind-provision: linking"
        find "$build/obj" -name '*.o' | sed 's/.*/"&"/' > "$build/link.rsp"
        "$zig" cc -shared -o "$game/swgame.so.tmp" "@$build/link.rsp"
        mv "$game/swgame.so.tmp" "$game/swgame.so"

        echo "$gamelib_id" > "$game/swgame.so.id"

        # The intermediates (a 13.5 GiB base NCA, the update NCA and the
        # object files) are what a rebuild resumes from; keeping them costs
        # ~20 GiB but saves the 15-minute extraction. `stateDir/build` can be
        # deleted by hand — the provisioner re-creates it.
        echo "savage-wind-provision: intermediates kept in $work ($(du -sh "$work" | cut -f1))"
        echo "$want" > "$stamp"
      fi

      # 4. Translate every shader the RomFS ships, so areas do not stutter when
      #    they first come into view. Its own stamp, so adding or changing this
      #    step runs without rebuilding the game code.
      #    SAVAGEWIND_PRECOMPILE_NO_PIPELINES skips the Vulkan device (this runs
      #    without a display); the driver's pipelines still build on first use.
      shaders_stamp="$state/.shaders"
      if [ "$(cat "$shaders_stamp" 2>/dev/null || true)" != "$want" ]; then
        echo "savage-wind-provision: precompiling shaders"
        SAVAGEWIND_PRECOMPILE_NO_PIPELINES=1 \
          ${release}/usr/bin/savagewind --precompile-shaders "$game" >/dev/null 2>&1 || \
          echo "savage-wind-provision: shader precompilation failed; the game will translate them as they appear" >&2
        echo "$want" > "$shaders_stamp"
      fi

      echo "savage-wind-provision: done, the game is in $game ($(du -sh "$game" | cut -f1))"
    '';
  };

  # A fetchable asset: URL plus the SRI hash `nix hash file` prints.
  urlHash = types.submodule {
    options = {
      url = mkOption { type = types.str; };
      hash = mkOption { type = types.str; };
    };
  };

  sourceDrv = {
    base = pkgs.fetchurl { inherit (cfg.source.base) url hash; };
    update = pkgs.fetchurl { inherit (cfg.source.update) url hash; };
  };

  # `sha256sum -c` wants base16; the option carries SRI.
  keysHashHex = lib.convertHash {
    hash = cfg.source.keys.hash;
    toHashFormat = "base16";
  };

  launcher = pkgs.writeShellApplication {
    name = "savagewind";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ ! -x ${escapeShellArg "${gameDir}/swgame.so"} ]; then
        echo "savagewind: the game code is missing; run \`savage-wind-provision\`." >&2
        exit 1
      fi
      export SAVAGEWIND_DATA_ROOT=${escapeShellArg cfg.stateDir}
      export SAVAGEWIND_SETTINGS=${escapeShellArg "${cfg.stateDir}/savagewind.ini"}
      export LD_LIBRARY_PATH=${release}/usr/lib:${runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
      ${optionalString (cfg.font != null) ''
        export SAVAGEWIND_FONT=${escapeShellArg cfg.font}
      ''}
      ${concatStringsSep "\n" (
        mapAttrsToList (name: value: "export ${name}=${escapeShellArg value}") cfg.settings
      )}
      exec ${release}/usr/bin/savagewind "$@"
    '';
  };

  # `--config` opens the screen that edits settings and re-runs setup.
  configLauncher = pkgs.writeShellScriptBin "savagewind-config" ''
    exec ${launcher}/bin/savagewind --config "$@"
  '';

  icon = pkgs.runCommand "zelda-breath-of-the-wild-icon" { } ''
    install -Dm644 ${../../../assets/savage-wind/icon-512.png} \
      $out/share/icons/hicolor/512x512/apps/zelda-breath-of-the-wild.png
    install -Dm644 ${../../../assets/savage-wind/icon-256.png} \
      $out/share/icons/hicolor/256x256/apps/zelda-breath-of-the-wild.png
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "zelda-breath-of-the-wild";
    desktopName = "塞尔达传说：旷野之息";
    genericName = "The Legend of Zelda: Breath of the Wild";
    comment = "Breath of the Wild, statically recompiled to native code";
    exec = "savagewind --play";
    icon = "zelda-breath-of-the-wild";
    categories = [ "Game" ];
    startupNotify = false;
    singleMainWindow = true;
    actions = {
      config = {
        name = "Savage Wind Configuration";
        exec = "savagewind-config";
      };
    };
  };
in
{
  options.modules.desktop.savage-wind = {
    enable = mkEnableOption "Savage Wind Recomp";

    version = mkOption {
      type = types.str;
      default = "0.4.1-alpha.4";
      description = "Upstream release tag, used for the store path name only.";
    };

    appImage = mkOption {
      type = types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            description = ''
              The x86_64 release asset. Pin a tag, not `releases/latest`: the
              latest asset changes and the hash stops matching.
            '';
          };
          hash = mkOption {
            type = types.str;
            description = "SRI hash of the AppImage, as printed by `nix hash file`.";
          };
        };
      };
      description = "The upstream `Savage_Wind-<version>-x86_64.AppImage`.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/savagewind";
      description = ''
        Writable state: `extracted/` (game files and the recompiled library),
        `savagewind.ini` and the saves. Set as `SAVAGEWIND_DATA_ROOT`.
      '';
    };

    user = mkOption {
      type = types.str;
      default = myvars.username or "nobody";
      description = ''
        Owner of `stateDir`; the provisioner and the game run as this user.
        Defaults to `myvars.username` in this repository.
      '';
    };

    source = mkOption {
      type = types.submodule {
        options = {
          base = mkOption {
            type = urlHash;
            description = "Base game, XCI or NSP.";
          };
          update = mkOption {
            type = urlHash;
            description = ''
              The 1.9.0 update NSP. Savage Wind supports 1.8.2 and 1.9.0; 1.8.2
              is not maintained, so this is the version to use.
            '';
          };
          keys = mkOption {
            type = urlHash;
            description = ''
              A zip holding `prod.keys`. Downloaded into `stateDir/keys` with
              mode 0600 — never through `fetchurl`, which would copy the keys
              into the world-readable store.
            '';
          };
          baseId = mkOption {
            type = types.str;
            default = "01007EF00011E000";
            description = "Base title id, used to pick the right NCAs.";
          };
          updateId = mkOption {
            type = types.str;
            default = "01007EF00011E800";
            description = "Update title id.";
          };
        };
      };
      description = "Game files and keys, fetched by the provisioner.";
    };

    font = mkOption {
      type = types.nullOr types.str;
      default = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf";
      description = ''
        TrueType font the game falls back to when the Switch fonts are absent,
        exported as `SAVAGEWIND_FONT`. It must be TrueType: the game's font
        engine cannot read CFF outlines such as Noto Sans CJK's. The default is
        DejaVu Sans, which upstream names for Linux.
      '';
    };

    ini = mkOption {
      type = types.attrsOf (types.either types.int types.str);
      default = {
        fullscreen = 1;
        fullscreen_mode = "borderless";
      };
      example = {
        fullscreen = 1;
        fullscreen_mode = "borderless";
        frame_rate = 120;
        antialias = "smaa";
      };
      description = ''
        Keys for `savagewind.ini`. Every activation writes these into the file,
        so the configuration wins over the in-game menu for the keys named here;
        every other key stays as the player left it. Move a setting out of this
        set to hand it back to the menu.

        `fullscreen_mode` is `auto`, `borderless` or `exclusive`; the keys and
        their ranges are the ones the in-game menu shows.
      '';
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        SAVAGEWIND_CORES = "8";
        # One line a second with the fused orientation and the sensor
        # stream's health, for working out why gyro is not responding.
        SAVAGEWIND_MOTION_LOG = "1";
      };
      description = "Extra `SAVAGEWIND_*` environment variables for the launcher.";
    };
  };

  config = mkIf cfg.enable {
    # The provisioner enumerates Vulkan devices through the installer path and
    # writes into `stateDir`, so it runs as the owning user rather than inside
    # a build sandbox.
    systemd.services.savage-wind-provision = {
      description = "Build Savage Wind game data from the declared sources";
      wantedBy = [ "multi-user.target" ];
      before = [ "graphical.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
      };
      script = "${provisionScript}/bin/savage-wind-provision";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
      "d ${cfg.stateDir}/keys 0700 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
    ];

    environment.systemPackages = [
      launcher
      configLauncher
      desktopItem
      icon
      provisionScript
    ];

    # Controllers with rumble, LEDs and gyro need the hidraw nodes; these are
    # the rules Steam ships, and the pad still works through the kernel driver
    # without them.
    services.udev.packages = [ pkgs.steam-devices-udev-rules ];
  };
}
