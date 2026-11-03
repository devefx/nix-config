{
  config,
  lib,
  pkgs,
  myvars ? { },
  ...
}:
# TotK Recomp — the static recompilation of Tears of the Kingdom.
#
# Everything comes from URLs: `totk-provision` (a systemd oneshot) fetches the
# cartridge dump, the update, the upstream release, the console keys and the
# firmware, then runs the upstream installer. A fresh install needs nothing but
# the network and this configuration.
#
# The game lands in a writable folder rather than a read-only store path: it
# writes `totk.ini`, `build-cache/` (mod code patches rebuild themselves) and
# Mesa's shader cache next to its own binary. Only the saves are pulled out into
# `stateDir/profile` so they can be backed up without the 19 GB around them.
#
# Every path is an option; game files and `prod.keys` are `str`, never `path`,
# because a `path` would copy them into the world-readable nix store. The keys
# are downloaded by the provisioner into a 0700 folder for the same reason.
let
  inherit (lib)
    concatStringsSep
    escapeShellArg
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalString
    types
    ;

  cfg = config.modules.desktop.totk;

  # A fetchable asset: URL plus the SRI hash `nix hash file` prints.
  urlHash = types.submodule {
    options = {
      url = mkOption { type = types.str; };
      hash = mkOption { type = types.str; };
    };
  };

  # `sha256sum -c` wants base16; the option carries SRI. Only reached through
  # `provisionScript`, which exists only when `source` is set.
  keysHashHex = lib.convertHash {
    hash = cfg.source.keys.hash;
    toHashFormat = "base16";
  };

  # `fetchurl` lands in the store as 0444; an AppImage has to be executable
  # before `--appimage-extract` will run.
  makeAppImage =
    src:
    pkgs.runCommand "totk-setup-appimage" { } ''
      install -Dm755 ${src} $out/bin/TotK-Setup-x86_64.AppImage
    '';

  # The release's bundled clang, hactool, ninja and Python all assume
  # /lib64/ld-linux-x86-64.so.2 is a glibc loader. On NixOS it is a stub, so
  # every ELF gets its interpreter pointed at the nix glibc and its RUNPATH
  # widened with zlib and libstdc++; `clang` becomes a wrapper that passes
  # --dynamic-linker through, so the hostcheck and totk it compiles are
  # runnable too.
  #
  # Idempotent on purpose: patchelf rewrites the ELF even when the values are
  # unchanged, and the installer keys its `prepare` step on the translator
  # binary — rewriting `totk_xlate` on every run would discard the 125 s shader
  # pass. Expects `$squash`, `$glibc`, `$zlib` and `$gcc` in scope.
  patchToolchain = ''
    patch_elf() {
      local f=$1 old
      [ -f "$f" ] || return 0
      if [ "$(patchelf --print-interpreter "$f" 2>/dev/null)" = "$glibc/lib/ld-linux-x86-64.so.2" ]; then
        return 0
      fi
      old=$(patchelf --print-rpath "$f" 2>/dev/null || true)
      patchelf \
        --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" \
        --set-rpath "''${old:+$old:}$glibc/lib:$zlib/lib:$gcc/lib" \
        "$f"
    }
    for f in llvm/bin/clang-23 llvm/bin/lld llvm/bin/llvm-ar \
             llvm/bin/llvm-objcopy bin/hactool bin/totk_xlate bin/ninja; do
      patch_elf "$squash/$f"
    done

    # Python keeps $ORIGIN so numpy and friends find the bundled libpython, and
    # gets zlib/libstdc++ for their extension modules (DT_RUNPATH is not
    # inherited by dlopen'd objects, so LD_LIBRARY_PATH has to cover the rest).
    if [ -f "$squash/python/bin/python3" ] \
      && [ "$(patchelf --print-rpath "$squash/python/bin/python3")" != "\$ORIGIN/../lib:$glibc/lib:$zlib/lib:$gcc/lib" ]; then
      patchelf \
        --set-interpreter "$glibc/lib/ld-linux-x86-64.so.2" \
        --set-rpath "\$ORIGIN/../lib:$glibc/lib:$zlib/lib:$gcc/lib" \
        "$squash/python/bin/python3"
    fi

    wrapper="$squash/llvm/bin/clang"
    if [ ! -f "$wrapper" ] || ! grep -q "dynamic-linker=$glibc" "$wrapper" 2>/dev/null; then
      rm -f "$wrapper"
      cat > "$wrapper" <<WRAPPER
    #!/bin/sh
    exec "$squash/llvm/bin/clang-23" \
      -Wl,--dynamic-linker=$glibc/lib/ld-linux-x86-64.so.2 \
      -Wl,-rpath=$glibc/lib \
      "\$@"
    WRAPPER
      chmod +x "$wrapper"
      ln -sf clang "$squash/llvm/bin/clang++"
    fi
  '';

  # NixOS keeps the Vulkan ICDs in /run/opengl-driver and has no
  # /etc/vulkan/icd.d, so the installer's host probe finds no device unless
  # told. List every ICD there rather than naming one vendor's: radeon for AMD,
  # nvidia_icd for NVIDIA, intel_icd for Intel.
  selectVulkanIcd = ''
    if [ -z "''${VK_ICD_FILENAMES:-}" ] && [ -d /run/opengl-driver/share/vulkan/icd.d ]; then
      found=$(find /run/opengl-driver/share/vulkan/icd.d -maxdepth 1 -name '*.json' 2>/dev/null | paste -sd: -)
      if [ -n "$found" ]; then
        export VK_ICD_FILENAMES="$found"
      fi
    fi
  '';

  # Yuzu/Eden's prod.keys carries a handful of 34-hex `master_kek_source_*`
  # lines (should be 32); hactool aborts the whole keyset on the first one.
  # Usage: clean_keyset <input> <output>; the output is left mode 0600.
  cleanKeyset = ''
    clean_keyset() {
      awk -F'=' '
        /^[[:space:]]*#/ || NF < 2 { print; next }
        {
          name = $1; val = $2
          gsub(/[[:space:]]/, "", name); gsub(/[[:space:]]/, "", val)
          if (length(val) == 34) next
          print name " = " val
        }
      ' "$1" > "$2"
      chmod 600 "$2"
    }
  '';

  # Where the provisioner writes the game.
  gameDir = "${cfg.stateDir}/game";

  # `totk` has DT_RUNPATH "$ORIGIN", and the loader searches LD_LIBRARY_PATH
  # before RUNPATH, so naming them here is enough — no patchelf on the 263 MB
  # executable. Their own RUNPATHs pull in alsa, X11, libdrm and the rest.
  # Being in this derivation's closure also roots the store paths, so
  # `nix-collect-garbage` cannot take the libraries away.
  gameLibs = lib.makeLibraryPath [
    pkgs.sdl3
    pkgs.vulkan-loader
  ];

  launcher = pkgs.writeShellApplication {
    name = "totk";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      game=${escapeShellArg gameDir}

      if [ ! -x "$game/totk" ]; then
        echo "totk: $game/totk is missing; run \`totk-provision\` (or systemctl start totk-provision)." >&2
        exit 1
      fi

      export LD_LIBRARY_PATH=${gameLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

      # SDL picks X11 when XWayland is around, and XWayland on a scale=2
      # compositor hands X clients a logical-sized screen: the game asks for
      # 3840x2160, gets 1896x2006, renders 1080p, FSRs it up, then gets scaled
      # again by XWayland and once more by the compositor. Naming the Wayland
      # backend keeps the swapchain at the real 3840x2160.
      if [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        export SDL_VIDEODRIVER="''${SDL_VIDEODRIVER:-wayland}"
      fi

      # Saves live apart from the game so they survive a re-unpack.
      export TOTK_PROFILE_DIR=${escapeShellArg "${cfg.stateDir}/profile"}

      ${concatStringsSep "\n" (
        mapAttrsToList (name: value: "export ${name}=${escapeShellArg value}") cfg.settings
      )}

      cd "$game"
      exec ./totk "$@"
    '';
  };

  # The game files come from the URLs declared in `cfg.source`, and a systemd
  # oneshot builds the game from them. A plain derivation cannot
  # do the build: the installer's check step enumerates Vulkan devices, and
  # /dev/dri is not visible inside the nix build sandbox (measured: `NO-DRI`
  # with sandbox on, `card1`/`renderD128` with it off). Running it from a
  # service keeps the sandbox strict for everything else.
  sourceDrv = {
    base = pkgs.fetchurl { inherit (cfg.source.base) url hash; };
    update = pkgs.fetchurl { inherit (cfg.source.update) url hash; };
    appImage = makeAppImage (pkgs.fetchurl { inherit (cfg.source.appImage) url hash; });
    firmware =
      if cfg.source.firmware == null then
        null
      else
        pkgs.fetchurl { inherit (cfg.source.firmware) url hash; };
  };

  # What the stamps record: rebuild when any of these changes. The firmware
  # counts — it decides the shared fonts the game draws its own text with — and
  # so does the keyset, which lives outside the store but decides whether
  # hactool can open the NCAs at all.
  provisionSources = [
    sourceDrv.base
    sourceDrv.update
    sourceDrv.appImage
    cfg.source.keys.hash
  ]
  ++ optional (sourceDrv.firmware != null) sourceDrv.firmware;

  provisionScript = pkgs.writeShellApplication {
    name = "totk-provision";
    runtimeInputs = [
      pkgs.patchelf
      pkgs.nsz
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.curl
      pkgs.unzip
    ];
    text = ''
      set -euo pipefail

      state=${escapeShellArg cfg.stateDir}
      game="$state/game"
      work="$state/build"
      squash="$work/squashfs-root"
      stamp="$state/.built"
      src_stamp="$state/.sources"
      want=${escapeShellArg (concatStringsSep " " provisionSources)}

      if [ -x "$game/totk" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$want" ]; then
        echo "totk-provision: already built from these sources"
        exit 0
      fi

      # A different source set invalidates every intermediate: the existence
      # checks below would otherwise keep an old firmware, update or keyset
      # forever. A plain retry after a failure keeps them (`src_stamp` matches).
      if [ "$(cat "$src_stamp" 2>/dev/null || true)" != "$want" ]; then
        echo "totk-provision: sources changed, discarding intermediates"
        rm -rf "$work" "$state/keys"
      fi

      glibc=${pkgs.glibc}
      zlib=${pkgs.zlib}
      gcc=${pkgs.gcc.cc.lib}
      sdl3=${pkgs.sdl3}
      vk=${pkgs.vulkan-loader}

      mkdir -p "$work"

      # The installer refuses a non-empty destination, and expects it to exist.
      echo "totk-provision: preparing $game"
      rm -rf "$game"
      mkdir -p "$game"

      # 0. Keys, into a 0700 directory. Not through `fetchurl`: the nix store is
      #    world-readable, and these are the console's console-unique keys.
      keys_dir="$state/keys"
      prod_keys="$keys_dir/prod.keys"
      if [ ! -f "$prod_keys" ]; then
        echo "totk-provision: fetching prod.keys"
        mkdir -p "$keys_dir"
        chmod 700 "$keys_dir"
        zip="$keys_dir/keys.zip"
        curl -fsSL -o "$zip" ${escapeShellArg cfg.source.keys.url}
        echo "${keysHashHex}  $zip" | sha256sum -c - >/dev/null
        unzip -o -q "$zip" -d "$keys_dir"
        rm -f "$zip"
        chmod 600 "$keys_dir"/*.keys 2>/dev/null || true
      fi

      # 1. The installer reads NSP, not NSZ.
      update_nsp="$work/update.nsp"
      if [ ! -f "$update_nsp" ]; then
        echo "totk-provision: decompressing the update (nsz -D)"
        export HOME="$work/nsz-home"
        mkdir -p "$HOME/.switch"
        cp "$prod_keys" "$HOME/.switch/prod.keys"
        nsz -D -o "$work" ${escapeShellArg sourceDrv.update} >/dev/null
        found=$(find "$work" -maxdepth 1 -name '*.nsp' | head -1)
        if [ -z "$found" ]; then
          echo "totk-provision: nsz produced no .nsp" >&2
          exit 1
        fi
        mv "$found" "$update_nsp"
      fi

      # 2. Unpack the release toolchain.
      if [ ! -x "$squash/python/bin/python3" ]; then
        echo "totk-provision: unpacking the release"
        ( cd "$work" && ${escapeShellArg "${sourceDrv.appImage}/bin/TotK-Setup-x86_64.AppImage"} --appimage-extract >/dev/null )
      fi

      # 2b. Firmware, for the shared fonts the game draws its own text with.
      fw_dir="$work/firmware"
      ${optionalString (sourceDrv.firmware != null) ''
        if [ ! -f "$fw_dir/.unpacked" ]; then
          echo "totk-provision: unpacking the firmware"
          mkdir -p "$fw_dir"
          unzip -o -q ${escapeShellArg sourceDrv.firmware} -d "$fw_dir"
          touch "$fw_dir/.unpacked"
        fi
      ''}

      # 3. Adapt it to NixOS.
      ${patchToolchain}

      # 4. Drop the 34-hex lines that abort hactool's keyset load.
      ${cleanKeyset}
      keys_clean="$work/prod.keys.clean"
      clean_keyset "$prod_keys" "$keys_clean"

      # Everything the installer needs is on disk now; a failure from here on
      # can be retried without re-downloading.
      echo "$want" > "$src_stamp"

      # 5. Build.
      export LD_LIBRARY_PATH="$sdl3/lib:$vk/lib:$gcc/lib:$zlib/lib:$glibc/lib:/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      ${selectVulkanIcd}

      args=(
        --base ${escapeShellArg sourceDrv.base}
        --update "$update_nsp"
        --keys "$keys_clean"
        --lang ${escapeShellArg cfg.source.language}
        --dest "$game"
        --temp "$work/temp"
      )
      ${optionalString (sourceDrv.firmware != null) ''
        args+=(--firmware "$fw_dir")
      ''}

      "$squash/python/bin/python3" -m installer "''${args[@]}"

      echo "$want" > "$stamp"
      echo "totk-provision: done, the game is in $game"
    '';
  };

  # The cover art lives in this repository: it is a launcher asset, not game
  # data, and the desktop entry must not depend on the archive server being up.
  # The theme name inside the store is the game's, not the folder's: that is
  # what `Icon=` in the desktop entry points at.
  icon = pkgs.runCommand "zelda-tears-of-the-kingdom-icon" { } ''
    install -Dm644 ${../../../assets/totk/icon-512.png} \
      $out/share/icons/hicolor/512x512/apps/zelda-tears-of-the-kingdom.png
    install -Dm644 ${../../../assets/totk/icon-256.png} \
      $out/share/icons/hicolor/256x256/apps/zelda-tears-of-the-kingdom.png
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "zelda-tears-of-the-kingdom";
    desktopName = "塞尔达传说：王国之泪";
    genericName = "The Legend of Zelda: Tears of the Kingdom";
    comment = "Tears of the Kingdom, statically recompiled to native code";
    exec = "totk";
    icon = "zelda-tears-of-the-kingdom";
    categories = [ "Game" ];
    startupNotify = false;
    singleMainWindow = true;
  };
in
{
  options.modules.desktop.totk = {
    enable = mkEnableOption "TotK Recomp";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/totk";
      description = ''
        Holds `game/` (the game the provisioner builds), `profile/` (the saves —
        the only thing worth backing up) and the `.built` stamp.
      '';
    };

    user = mkOption {
      type = types.str;
      default = myvars.username or "nobody";
      description = ''
        Owner of `stateDir`; the game runs as this user. Defaults to
        `myvars.username` in this repository; set it explicitly when the module
        is imported from another flake.
      '';
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        TOTK_PERF_OVERLAY = "fps";
        TOTK_LANG = "zh-Hans";
      };
      description = ''
        Extra `TOTK_*` environment variables, exported by the launcher. These
        override `totk.ini`, so they are the declarative way to pin a setting.
      '';
    };

    source = mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            base = mkOption {
              type = urlHash;
              description = "Base game (1.0.0), XCI or NSP.";
            };
            update = mkOption {
              type = urlHash;
              description = "The 1.1.0, 1.2.1 or 1.4.3 update, NSZ or NSP.";
            };
            appImage = mkOption {
              type = urlHash;
              description = "The upstream `TotK-Setup-x86_64.AppImage`.";
            };
            keys = mkOption {
              type = urlHash;
              description = ''
                A zip holding `prod.keys` (and `title.keys`). Downloaded by the
                provisioner into `stateDir/keys` with mode 0600 — never through
                `fetchurl`, which would copy the keys into the world-readable
                nix store.
              '';
            };
            firmware = mkOption {
              type = types.nullOr urlHash;
              default = null;
              description = ''
                Switch firmware as a zip of `Contents/registered` (238 NCA
                files, ~325 MB). Needed for the Chinese, Korean and Traditional
                Chinese shared fonts the game itself draws; without it that text
                falls back to blanks.
              '';
            };
            language = mkOption {
              type = types.str;
              default = "en-US";
              description = "Switch language code (en-US, ja, zh-Hans, ...).";
            };
          };
        }
      );
      default = null;
      description = ''
        The provisioner fetches the game files, the update, the release, the
        keys and the firmware, then runs the installer.

        A `systemd` oneshot does the work rather than a derivation, because the
        installer's check step enumerates Vulkan devices and `/dev/dri` is not
        visible inside the nix build sandbox.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.source != null;
        message = "modules.desktop.totk: `source` is required — it names the cartridge dump, the update, the release, the keys and the firmware.";
      }
    ];

    # The build runs in a service, not a derivation: the installer's check
    # step enumerates Vulkan devices and /dev/dri is not visible inside the nix
    # build sandbox. Runs as the owning user so it can write `stateDir` and read
    # the console keys it downloads there.
    systemd.services.totk-provision = mkIf (cfg.source != null) {
      description = "Build TotK Recomp game data from the declared sources";
      wantedBy = [ "multi-user.target" ];
      # Nothing graphical depends on it, so a first boot is not held up.
      before = [ "graphical.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
      };
      script = "${provisionScript}/bin/totk-provision";
    };

    # The in-game menu and the performance overlay are Dear ImGui drawn with
    # stb_truetype, which reads TrueType outlines but not CFF/OTF. For Chinese
    # (and Korean) it looks for a system font at the usual Linux locations,
    # `/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc` first — a path that
    # does not exist on NixOS, so every menu glyph renders as `?`.
    #
    # WenQuanYi Zen Hei is TrueType and covers Simplified Chinese, so it fills
    # that slot. The filename stays Noto's because the binary only looks at the
    # path. Nothing else on NixOS scans /usr/share/fonts — fontconfig points at
    # /run/current-system/sw/share/fonts — so this only affects the game.
    systemd.tmpfiles.rules = [
      # Menu font slot (see the comment above).
      "d /usr/share/fonts/noto-cjk 0755 root root -"
      "L+ /usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc - - - - ${pkgs.wqy_zenhei}/share/fonts/truetype/wqy-zenhei.ttc"

      # The provisioner creates `game/` itself; only the parents are declared so
      # a rebuild never races a tmpfiles rule.
      "d ${cfg.stateDir} 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
      "d ${cfg.stateDir}/profile 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
    ];

    environment.systemPackages = [
      launcher
      desktopItem
      icon
    ]
    ++ optional (cfg.source != null) provisionScript;
  };
}
