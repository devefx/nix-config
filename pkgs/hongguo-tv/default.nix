{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  makeDesktopItem,
  wrapGAppsHook3,
  adwaita-icon-theme,
  dbus,
  glib-networking,
  gsettings-desktop-schemas,
  gst_all_1,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  xdg-utils,
}:
# 红果短剧 (Hongguo short dramas) desktop client.
#
# Upstream only ships a Linux x86_64 AppImage, and it deliberately bundles
# nothing but the two binaries: the AppRun script execs `usr/bin/hongguo-tv`
# and expects the host to provide WebKitGTK 4.1, GTK 3, GStreamer and the
# HEVC/AAC decoders. So the AppImage is unpacked here and the ELF is patched
# against nixpkgs' WebKitGTK instead of being run through
# `appimageTools.wrapAppImage` (whose FHS sandbox would just hand it the same
# libraries from a chroot).
#
# `hongguo-tv` is the GTK/WebKit shell; `hongguo-tv-core` is a static Go
# helper it spawns from its own directory, so both must stay next to each
# other. They live in `libexec` and only the wrapper is exposed in `bin`.
let
  pname = "hongguo-tv";
  version = "0.2.117";

  src = fetchurl {
    url = "https://github.com/aston314/hongguo-tv-releases/releases/download/linux-v${version}-test.1/hongguo-desktop-${version}-x86_64.AppImage";
    hash = "sha256-gULDpBDDMG0t8QqtiZWrX5a7b2hZPq8Fdswe4oRyaes=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "红果短剧";
    genericName = "Short Drama Player";
    comment = "红果短剧 desktop client";
    exec = "${pname} %U";
    icon = pname;
    categories = [
      "AudioVideo"
      "Video"
    ];
    # Wails sets the Wayland app_id from the Go module path's last segment and
    # capitalises it, so the running window reports `Hongguo-tv` (verified with
    # `niri msg windows` on both 0.2.115 and 0.2.117). Matching that instead of
    # `pname` is what lets the compositor associate the window with this desktop
    # entry, so the taskbar shows the app icon rather than a generic fallback.
    startupWMClass = "Hongguo-tv";
  };
in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    # TLS for the WebKit network process (libsoup 3 looks up the GIO TLS
    # module) and the schemas/icon theme GTK 3 expects to find at runtime.
    glib-networking
    gsettings-desktop-schemas
    adwaita-icon-theme
    dbus
    # WebKit renders <video> through GStreamer; `gst-libav` is what supplies
    # the HEVC and AAC decoders this app plays everything with.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
  ];

  # `gappsWrapperArgs` is still populated by the hook, but wrapping is done
  # by hand below so the real ELF can stay in `libexec` next to its core.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/${pname} $out/bin
    cp -a ${appimageContents}/usr/bin/. $out/libexec/${pname}/
    chmod +x $out/libexec/${pname}/hongguo-tv $out/libexec/${pname}/hongguo-tv-core

    install -Dm644 ${appimageContents}/hongguo-tv.png \
      $out/share/icons/hicolor/1024x1024/apps/${pname}.png
    install -Dm644 ${desktopItem}/share/applications/${pname}.desktop \
      $out/share/applications/${pname}.desktop

    runHook postInstall
  '';

  postFixup = ''
    wrapGApp $out/libexec/${pname}/hongguo-tv \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}

    ln -s $out/libexec/${pname}/hongguo-tv $out/bin/${pname}
  '';

  meta = {
    description = "红果短剧 desktop client (WebKitGTK shell over a Go core)";
    homepage = "https://github.com/aston314/hongguo-tv-releases";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
