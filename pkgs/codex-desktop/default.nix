{
  lib,
  pkgs,
}:

# OpenAI ships Codex/ChatGPT desktop as a Debian package. NixOS cannot use
# dpkg state directly, so this wrapper extracts the official .deb and runs it
# inside an FHS environment with the Electron runtime libraries it needs.
let
  version = "26.810.41047";

  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    sha256 = "sha256-eHFfo80Tb/ZwcNqnaBmtrsxbQumYUVWWWWRdzh+/KvM=";
  };

  chatgpt-files = pkgs.stdenv.mkDerivation {
    pname = "chatgpt";
    inherit version src;

    nativeBuildInputs = [ pkgs.dpkg ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      unpack_dir="$TMPDIR/unpacked"
      mkdir -p "$unpack_dir" "$out/bin" "$out/lib" "$out/share"
      dpkg-deb -x "$src" "$unpack_dir"
      cp -a "$unpack_dir/usr/bin/." "$out/bin/"
      cp -a "$unpack_dir/usr/lib/chatgpt" "$out/lib/chatgpt"
      cp -a "$unpack_dir/usr/share/applications/." "$out/share/applications/"
      cp -a "$unpack_dir/usr/share/pixmaps/." "$out/share/pixmaps/"
      install -Dm0644 "$unpack_dir/usr/share/pixmaps/chatgpt.png" \
        "$out/share/icons/hicolor/256x256/apps/chatgpt.png"
      runHook postInstall
    '';
  };

  fhs = pkgs.buildFHSEnv {
    name = "chatgpt";

    targetPkgs =
      p:
      [
        chatgpt-files
      ]
      ++ (with p; [
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
        libglvnd
        libnotify
        libusb1
        libxcb
        libxkbcommon
        mesa
        nspr
        nss
        openssl
        pango
        pipewire
        stdenv.cc.cc.lib
        systemd
        wayland
        xz
        zlib
        zstd
      ]);

    runScript = "chatgpt";
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "chatgpt";
    desktopName = "ChatGPT";
    comment = "ChatGPT by OpenAI";
    icon = "chatgpt";
    exec = "chatgpt %U";
    categories = [
      "Development"
      "Utility"
    ];
    mimeTypes = [
      "x-scheme-handler/codex"
    ];
  };

  icon = pkgs.runCommand "chatgpt-icons" { } ''
    mkdir -p "$out/share/icons/hicolor/256x256/apps"
    cp "${chatgpt-files}/share/icons/hicolor/256x256/apps/chatgpt.png" \
      "$out/share/icons/hicolor/256x256/apps/chatgpt.png"
  '';
in
pkgs.buildEnv {
  name = "chatgpt-desktop";
  paths = [
    fhs
    desktopItem
    icon
  ];

  meta = {
    description = "Codex/ChatGPT desktop app from OpenAI's official Linux .deb";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
