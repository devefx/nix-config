{
  lib,
  stdenv,
  runCommandLocal,
  glibc,
  fetchurl,
  makeWrapper,
  buildEnv,
  makeDesktopItem,
  mkNixPak,
  glib,
  gtk3,
  gdk-pixbuf,
  pango,
  cairo,
  webkitgtk_4_1,
  webkitgtk_6_0,
  fontconfig,
  freetype,
  harfbuzz,
  dbus,
  alsa-lib,
  pulseaudio,
  libGL,
  libdrm,
  libgbm,
  libva,
  libvdpau,
  wayland,
  libxkbcommon,
  libx11,
  xkeyboard_config,
  libxcb,
  libxcb-keysyms,
  libxcb-util,
  libxcb-image,
  libxcb-render-util,
  libxcb-cursor,
  libxcb-wm,
  libxext,
  libxrandr,
  libxrender,
  libxcomposite,
  libxdamage,
  libxfixes,
  libxi,
  libxtst,
  libxcursor,
  libxinerama,
  libxkbfile,
  libxscrnsaver,
  libsm,
  libice,
  libudev-zero,
  geoclue2,
  libsecret,
  gsettings-desktop-schemas,
  ...
}:
let
  appId = "org.ime.desktop";
  # NOTE: this upstream URL is a rolling "latest" upload, not a
  # version-addressable one, so `version` is only a human-readable label for
  # when the hash below was last refreshed. Re-fetch with
  #   nix store prefetch-file --json --hash-type sha256 <url>
  # whenever the hash stops matching; the builds of 2026-10-08 serve
  # sha256-sbT+HAXKQre4nGFws14nFz3hB9ON/9lRrbcwUZJLuKc=.
  version = "2026-09-29";
  src = fetchurl {
    url = "https://desktop-updates.imem.app/uploads/iMe_Desktop_Linux.tar.xz";
    hash = "sha256-sbT+HAXKQre4nGFws14nFz3hB9ON/9lRrbcwUZJLuKc=";
  };
  icon = fetchurl {
    url = "https://imem.app/logo512.png";
    hash = "sha256-89D/v2C+10vtBWXNnl7eqNlrVg7FKmWeRFf8Qirl+XQ=";
  };
  runtimeLibs = [
    stdenv.cc.cc.lib
    glib
    gtk3
    gdk-pixbuf
    pango
    cairo
    webkitgtk_4_1
    webkitgtk_6_0
    fontconfig
    freetype
    harfbuzz
    dbus
    alsa-lib
    pulseaudio
    libGL
    libdrm
    libgbm
    libva
    libvdpau
    wayland
    libxkbcommon
    libx11
    libxcb
    libxcb-keysyms
    libxcb-util
    libxcb-image
    libxcb-render-util
    libxcb-cursor
    libxcb-wm
    libxext
    libxrandr
    libxrender
    libxcomposite
    libxdamage
    libxfixes
    libxi
    libxtst
    libxcursor
    libxinerama
    libxkbfile
    libxscrnsaver
    libsm
    libice
    libudev-zero
    geoclue2
    libsecret
    gsettings-desktop-schemas
  ];
  raw = stdenv.mkDerivation {
    pname = "ime-desktop-bin";
    inherit version src icon;

    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      mkdir -p $out/share/icons/hicolor/512x512/apps
      install -m0755 iMe $out/bin/iMe
      install -m0755 Updater $out/bin/Updater
      install -m0644 $icon $out/share/icons/hicolor/512x512/apps/${appId}.png

      runHook postInstall
    '';
  };
  libraryPath = lib.makeLibraryPath runtimeLibs;
  ime = stdenv.mkDerivation {
    pname = "ime-desktop";
    inherit version;

    nativeBuildInputs = [ makeWrapper ];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      mkdir -p $out/share/icons/hicolor/512x512/apps
      install -m0755 ${raw}/bin/iMe $out/bin/.iMe
      install -m0755 ${raw}/bin/Updater $out/bin/.Updater
      install -m0644 ${raw}/share/icons/hicolor/512x512/apps/${appId}.png \
        $out/share/icons/hicolor/512x512/apps/${appId}.png

      makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/iMe \
        --argv0 iMe \
        --prefix LD_LIBRARY_PATH : "${libraryPath}" \
        --add-flags "$out/bin/.iMe"
      makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 $out/bin/Updater \
        --argv0 Updater \
        --prefix LD_LIBRARY_PATH : "${libraryPath}" \
        --add-flags "$out/bin/.Updater"

      runHook postInstall
    '';

    meta = {
      description = "iMe desktop version of Telegram messaging app";
      homepage = "https://imem.app";
      license = lib.licenses.unfree;
      mainProgram = "iMe";
      platforms = lib.platforms.linux;
    };
  };
  # iMe (Telegram Desktop) decides whether it runs inside Flatpak with
  #   KSandbox::isFlatpak() { return QFileInfo("/.flatpak-info").exists(); }
  # nixpak always writes that file, so iMe then subscribes to
  # org.freedesktop.portal.Flatpak.UpdateMonitor. That name is not in the D-Bus
  # policy and no flatpak.portal exists on a plain NixOS host, so every call
  # returns AccessDenied -- and iMe retries with NO backoff (~1500/s). Measured
  # growth: ~190 KB/s of log, monotonically. Over a night this reached 15 GB of
  # log and ~22 GB RSS, then Qt aborted with SIGTRAP in its
  # QNetworkAccessManager thread.
  #
  # There is no nixpak option to disable the shim: modules/launch.nix:120 always
  # passes `--set FLATPAK_METADATA_TEMPLATE ...`, and launcher/main.go:264 keys
  # the whole binding on `os.LookupEnv("FLATPAK_METADATA_TEMPLATE")`. So the
  # wrapper script is patched below to drop that one `--set`, which makes
  # UseFlatpakMetadata false, so launcher/main.go:400-401 never runs
  # `--ro-bind ... /.flatpak-info`. Without the file iMe stops identifying as a
  # Flatpak and never creates the UpdateMonitor at all.
  #
  # Do NOT try to fix this by removing the [Application] group from
  # flatpak.info: xdg-desktop-portal authorises portal calls by that group, so
  # dropping it breaks theming with
  #   Portal operation not allowed: 键文件没有组"Application"
  # and the UpdateMonitor storm continues regardless.
  wrapped = mkNixPak {
    config =
      { sloth, ... }:
      {
        imports = [
          ./modules/gui-base.nix
          ./modules/network.nix
          ./modules/common.nix
        ];

        app.package = ime;
        app.binPath = "bin/iMe";
        flatpak.appId = appId;
        dbus.enable = true;

        bubblewrap = {
          bind.rw = [
            sloth.xdgDocumentsDir
            sloth.xdgDownloadDir
            sloth.xdgMusicDir
            sloth.xdgVideosDir
            sloth.xdgPicturesDir
          ];
          bind.ro = [
            [
              "${xkeyboard_config}/share/X11/xkb"
              "/usr/share/X11/xkb"
            ]
            [
              "${libx11}/share/X11/locale"
              "/usr/share/X11/locale"
            ]
          ];
          sockets = {
            x11 = false;
            wayland = lib.mkForce false;
            pipewire = true;
          };
          env = {
            GDK_PIXBUF_MODULE_FILE = "${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
            XKB_CONFIG_ROOT = "${xkeyboard_config}/share/X11/xkb";
            XNLSPATH = "${libx11}/share/X11/locale";
            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";
            WAYLAND_DISPLAY = sloth.env "WAYLAND_DISPLAY";
            XDG_RUNTIME_DIR = sloth.env "XDG_RUNTIME_DIR";
            # iMe's bundled Qt needs xkeyboard-config data available or it
            # crashes while parsing the KDE Wayland keymap.
            QT_QPA_PLATFORM = "wayland";
          };
        };
      };
  };
  # nixpak offers no way to turn the Flatpak shim off, but its launcher only
  # binds /.flatpak-info when FLATPAK_METADATA_TEMPLATE is present in the
  # environment (launcher/main.go:264, used at main.go:400-401). Dropping that
  # single `--set` from the generated wrapper removes the file from the sandbox
  # entirely, which is what stops iMe identifying as Flatpak and starting the
  # UpdateMonitor retry storm described above. Everything else in the wrapper
  # (bwrap args, D-Bus proxy args) is left untouched.
  #
  # NOTE: nixpak also exports config.env, which embeds the *unpatched*
  # config.script. Do not use config.env here or the shim comes back.
  #
  # The `sed` matches makeWrapper's output verbatim
  # (modules/launch.nix:120 `--set FLATPAK_METADATA_TEMPLATE`); if nixpak ever
  # changes how it serialises that variable this needs revisiting.
  script = runCommandLocal "nixpak-${appId}-noshim" { meta.mainProgram = "iMe"; } ''
    mkdir -p $out/bin
    sed '/^export FLATPAK_METADATA_TEMPLATE=/d' \
      ${wrapped.config.script}/bin/iMe > $out/bin/iMe
    chmod +x $out/bin/iMe
  '';

  # Every entry point has to go through the patched `script`: the shell command
  # via paths below, and the desktop entry via exePath. Deriving exePath from
  # wrapped.config.script instead silently re-enables the shim on the GUI launch
  # path only, which is precisely how this regressed the first time (coredumps
  # from 2026-10-05/06 still had FLATPAK_METADATA_TEMPLATE in the environment).
  exePath = lib.getExe script;
in
buildEnv {
  inherit (wrapped.config.script) name meta passthru;
  paths = [
    script
    (makeDesktopItem {
      name = appId;
      desktopName = "iMe";
      comment = "iMe desktop version of Telegram messaging app";
      tryExec = exePath;
      exec = "${exePath} -- %u";
      icon = "${ime}/share/icons/hicolor/512x512/apps/${appId}.png";
      startupNotify = true;
      startupWMClass = "iMe";
      terminal = false;
      type = "Application";
      categories = [
        "Chat"
        "Network"
        "InstantMessaging"
        "Qt"
      ];
      mimeTypes = [
        "x-scheme-handler/tg"
        "x-scheme-handler/tonsite"
      ];
      keywords = [
        "tg"
        "chat"
        "im"
        "messaging"
        "messenger"
        "iMe"
      ];
      actions.quit = {
        name = "Quit iMe";
        exec = "${exePath} -quit";
        icon = "application-exit";
      };
      extraConfig = {
        X-Flatpak = appId;
        SingleMainWindow = "true";
        X-GNOME-UsesNotifications = "true";
        X-GNOME-SingleWindow = "true";
      };
    })
  ];
}
