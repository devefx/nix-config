{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  graphite2,
  gsettings-desktop-schemas,
  gtk3,
  libGL,
  libX11,
  libXScrnSaver,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXrandr,
  libXtst,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libusb1,
  libxcb,
  libxkbcommon,
  libxshmfence,
  nspr,
  nss,
  openssl,
  pango,
  pipewire,
  systemd,
  util-linux,
  wayland,
  xz,
  zlib,
  zstd,
}:
# Binance desktop client (Electron), repackaged from the official Debian
# package. nixpkgs has no `binance`, and upstream ships only `.deb` for
# x86_64 (no AppImage), so the payload is extracted with `dpkg-deb` and
# `autoPatchelfHook` points it at nixpkgs' Electron runtime libraries instead
# of running it through an FHS sandbox.
#
# `autoPatchelfHook` also patches the bundled `keytar.node` (libsecret-backed
# credential storage) and the prebuilt `libffmpeg.so`, so no extra
# `--replace-needed` is required.
#
# Two upstream behaviours are worth knowing about:
#
#   * The archive ships a setuid `chrome-sandbox`, which the Nix store cannot
#     carry (it normalises modes to 0555/0444). Chromium then falls back to its
#     user-namespace sandbox, which NixOS enables by default, so the app starts
#     without `--no-sandbox` (verified on the niri host).
#   * `resources/app-update.yml` makes electron-updater try to self-update into
#     `$out/opt/Binance`, which is read-only. The attempt fails silently; the
#     only supported way to upgrade is to bump the hash below and rebuild.
let
  pname = "binance";
  version = "2.6.1";

  # The upstream URL is a rolling alias: Binance overwrites this exact object
  # on every release (the `.deb` control file carries the real version, 2.6.1
  # here). There is no versioned pool URL to pin, unlike OpenAI's APT repo, so
  # the hash below is what pins the build. When Binance ships a new build the
  # hash stops matching and the build fails with
  # "hash mismatch in fixed-output derivation" — that is the signal to bump:
  #
  #   nix store prefetch-file --json \
  #     https://download.binance.com/electron-desktop/linux/production/binance-amd64-linux.deb
  #
  # and copy `hash` (already SRI) plus the `Version:` line from
  # `dpkg-deb -f <file>.deb Version`.
  src = fetchurl {
    url = "https://download.binance.com/electron-desktop/linux/production/binance-amd64-linux.deb";
    hash = "sha256-dYDJBKSGe4QPS9xDu+R/IDoUiJPpaaF0XhGjLM4ctK0=";
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Binance";
    genericName = "Crypto Exchange";
    comment = "Buy & sell crypto in minutes";
    icon = pname;
    exec = "${pname} %U";
    # Upstream sets `StartupWMClass=Binance`; matching it is what lets the
    # compositor associate the Electron window with this entry, so the taskbar
    # shows the app icon instead of a generic fallback.
    startupWMClass = "Binance";
    categories = [ "Network" ];
    mimeTypes = [ "x-scheme-handler/binance" ];
  };
in
stdenv.mkDerivation {
  inherit pname version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    graphite2
    gsettings-desktop-schemas
    gtk3
    libGL
    libX11
    libXScrnSaver
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXrandr
    libXtst
    libdrm
    libgbm
    libnotify
    libpulseaudio
    libsecret
    libusb1
    libxcb
    libxkbcommon
    libxshmfence
    nspr
    nss
    openssl
    pango
    pipewire
    systemd
    util-linux
    wayland
    xz
    zlib
    zstd
  ];

  # The payload is a Debian archive, not a tarball: extract it in place and
  # keep the `/opt/Binance` layout the Electron binary expects ($ORIGIN RPATH
  # for libffmpeg.so / libEGL.so / libGLESv2.so).
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --extract "$src" .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/opt" "$out/bin" "$out/share"
    cp -a opt/Binance "$out/opt/Binance"
    cp -a usr/share/icons "$out/share/icons"

    # Electron disables Chromium's native Wayland text-input bridge by default.
    # Without these switches the app never exposes an input context to fcitx5,
    # so Pinyin appears dead even though fcitx5 is running. The same flags are
    # used by the other Electron wrappers in this repo; they are harmless on
    # X11.
    makeWrapper "$out/opt/Binance/binance" "$out/bin/${pname}" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-wayland-ime=true" \
      --add-flags "--wayland-text-input-version=3"

    install -Dm0644 ${desktopItem}/share/applications/${pname}.desktop \
      "$out/share/applications/${pname}.desktop"

    runHook postInstall
  '';

  meta = {
    description = "Binance desktop client (crypto exchange)";
    homepage = "https://www.binance.com/zh-CN/download";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
