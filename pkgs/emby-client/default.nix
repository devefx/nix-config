{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  pkgs,
}:

let
  runtimeLibs = with pkgs; [
    openssl.out
    libGL
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxscrnsaver
    libxtst
    libxcb
    libxkbcommon
    libdrm
    libva
    libpulseaudio
    alsa-lib
    libsecret
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "emby-client";
  version = "2.319.0";

  src = fetchurl {
    url = "https://pkg.emby.media/apt/pool/main/m/media.emby.client.beta/media.emby.client.beta_${finalAttrs.version}_amd64.deb";
    hash = "sha256-s6RIBvaG/ucGxalIkBKauMVbEgV649EOzE9hIQCATZs=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = runtimeLibs ++ (with pkgs; [
    stdenv.cc.cc.lib
    glib
    gtk3
    nss
    dbus
    atk
    at-spi2-core
    cups
    cairo
    pango
    fontconfig
    freetype
    expat
    libudev-zero
    mesa
    ocl-icd
    vulkan-loader
    zlib
  ]);

  autoPatchelfIgnoreMissingDeps = [
    "liblttng-ust.so.0"
  ];

  dontStrip = true;

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/emby-client" "$out/bin" "$out/share/applications" "$out/share/icons/hicolor"
    cp -a opt/Emby-Beta/. "$out/lib/emby-client/"
    chmod -R u+w "$out/lib/emby-client"

    ln -sf libicudata.so.72.1.0.3 "$out/lib/emby-client/resources/bin/libicudata.so.72"
    ln -sf libicuuc.so.72.1.0.3 "$out/lib/emby-client/resources/bin/libicuuc.so.72"
    ln -sf libicui18n.so.72.1.0.3 "$out/lib/emby-client/resources/bin/libicui18n.so.72"

    substituteInPlace "$out/lib/emby-client/resources/bin/Emby.Client.Electron1" \
      --replace-fail 'export LD_LIBRARY_PATH="$APP_DIR"' \
      'export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$APP_DIR"' \
      --replace-fail 'export LD_LIBRARY_PATH="$APP_DIR:$APP_DIR/extralibs/libva"' \
      'export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$APP_DIR:$APP_DIR/extralibs/libva"'

    # Emby restores a saved fullscreen window state before the JS fullscreen
    # manager is ready, so the UI never learns the window is already fullscreen
    # and the visible toggle button becomes a no-op. Re-sync the UI classes
    # once appHost is available, without firing fullscreenchange listeners
    # (those listeners can make Emby flip back out of fullscreen during startup).
    substituteInPlace "$out/lib/emby-client/resources/bin/web/native/interop/fullscreenmanager.js" \
      --replace-fail '        appHost = result;' '        appHost = result;
        setTimeout(function () {
            startFullScreenUiSync();
        }, 100);' \
      --replace-fail '    return manager;' '    function syncFullScreenUi() {
    if (manager.isFullScreen()) {
        document.documentElement.classList.add("isFullScreen");
    } else {
        document.documentElement.classList.remove("isFullScreen");
    }

    if (manager.isMaximized()) {
        document.documentElement.classList.add("isMaximized");
    } else {
        document.documentElement.classList.remove("isMaximized");
    }
    }

    function startFullScreenUiSync() {
        let syncAttempts = 0;
        const syncTimer = setInterval(function () {
            syncFullScreenUi();
            syncAttempts++;
            if (syncAttempts >= 40) {
                clearInterval(syncTimer);
            }
        }, 500);
    }

    return manager;'

    cp usr/share/applications/media.emby.client.beta.desktop "$out/share/applications/"
    cp -a usr/share/icons/hicolor/* "$out/share/icons/hicolor/"

    substituteInPlace "$out/share/applications/media.emby.client.beta.desktop" \
      --replace-fail "/opt/Emby-Beta/media.emby.client.beta" "$out/bin/media.emby.client.beta"

    makeWrapper "$out/lib/emby-client/media.emby.client.beta" "$out/bin/media.emby.client.beta" \
      --prefix PATH : "${lib.makeBinPath [
        pkgs.glibc.bin
        pkgs.coreutils
        pkgs.procps
        pkgs.gnugrep
        pkgs.gawk
        pkgs.gnused
        pkgs.xdg-utils
      ]}" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}" \
      --set XKB_CONFIG_ROOT "${pkgs.xkeyboard_config}/share/X11/xkb"

    runHook postInstall
  '';

  meta = {
    description = "Official Emby Linux desktop client (beta)";
    homepage = "https://emby.media";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "media.emby.client.beta";
    platforms = [ "x86_64-linux" ];
  };
})
