{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  wrapGAppsHook3,
  adwaita-icon-theme,
  dbus,
  glib-networking,
  gsettings-desktop-schemas,
  gst_all_1,
  gtk3,
  libayatana-appindicator,
  libsoup_3,
  wayland,
  webkitgtk_4_1,
  xdg-utils,
}:
# 短剧盒 (ShortDramaBox) desktop client — the successor of the old
# `hongguo-tv` AppImage: same idea (a Tauri/WebKit shell over a bundled
# backend) but actively maintained and shipped as a single ELF.
#
# Like the upstream AppImage's own AppRun says, it links against the
# distribution's GTK 3 / WebKitGTK 4.1 / GStreamer instead of bundling them, so
# the AppImage is unpacked here and the ELF is patched against nixpkgs'
# WebKitGTK rather than being run through `appimageTools.wrapAppImage` (whose
# FHS sandbox would hand it a different WebKit than the one the rest of the
# desktop uses).
#
# The tray icon is loaded with `dlopen("libayatana-appindicator3.so.1")`, which
# `autoPatchelfHook` cannot see, so it is added to `LD_LIBRARY_PATH` by hand.
let
  pname = "shortdramabox";
  version = "0.8.6";

  src = fetchurl {
    url = "https://github.com/kiroswu/hongguo-shortdramabox/releases/download/v${version}/ShortDramaBox-v${version}-amd64.AppImage";
    hash = "sha256-l0gD/UUDKuYdZMuy69E8v1TWRsBbsBKRvrfMkGCywoE=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  iconSizes = [
    "32x32"
    "64x64"
    "128x128"
    "256x256"
    "512x512"
  ];
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
    wayland
    # TLS for the WebKit network process (libsoup 3 looks up the GIO TLS
    # module) and the schemas/icon theme GTK 3 expects to find at runtime.
    glib-networking
    gsettings-desktop-schemas
    adwaita-icon-theme
    dbus
    # WebKit renders <video> through GStreamer; `gst-libav` supplies the HEVC
    # and AAC decoders the upstream FAQ tells users to install.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
  ];

  # `gappsWrapperArgs` is still populated by the hook, but wrapping happens by
  # hand below so the real ELF stays in `libexec` and only the wrapper lands in
  # `bin`.
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/${pname} $out/bin
    install -Dm755 ${appimageContents}/usr/bin/ShortDramaBox \
      $out/libexec/${pname}/ShortDramaBox

    # Upstream ships the desktop entry (with its Chinese name, keywords and
    # `StartupWMClass`) and the hicolor icons; keep them as-is so the window
    # keeps matching its launcher icon.
    install -Dm644 ${appimageContents}/usr/share/applications/ShortDramaBox.desktop \
      $out/share/applications/ShortDramaBox.desktop

    ${lib.concatMapStringsSep "\n" (size: ''
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/${size}/apps/shortdramabox.png \
        $out/share/icons/hicolor/${size}/apps/shortdramabox.png
    '') iconSizes}

    runHook postInstall
  '';

  postFixup = ''
    wrapGApp $out/libexec/${pname}/ShortDramaBox \
      --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libayatana-appindicator ]} \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]}

    ln -s $out/libexec/${pname}/ShortDramaBox $out/bin/ShortDramaBox
  '';

  meta = {
    description = "短剧盒 desktop client (WebKitGTK shell over a bundled backend)";
    homepage = "https://github.com/kiroswu/hongguo-shortdramabox";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "ShortDramaBox";
    platforms = [ "x86_64-linux" ];
  };
}
