{
  lib,
  stdenv,
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
  version = "2026-08-07";
  src = fetchurl {
    url = "https://desktop-updates.imem.app/uploads/iMe_Desktop_Linux.tar.xz";
    hash = "sha256-5XpZj39/GFuGSXd0iAarlyCUvb+fLRzVw3/1AHUoBr4=";
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
  exePath = lib.getExe wrapped.config.script;
in
buildEnv {
  inherit (wrapped.config.script) name meta passthru;
  paths = [
    wrapped.config.script
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
