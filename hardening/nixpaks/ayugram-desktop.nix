{
  lib,
  buildEnv,
  ayugramDesktop,
  mkNixPak,
  makeDesktopItem,
  ...
}:
# AyuGram Desktop — Telegram fork with extra privacy / UI tweaks.
# The package comes from the ayugram-desktop flake input (see flake.nix);
# its upstream binary cache is enabled in modules/base/nix.nix so we
# skip recompiling the tdesktop fork from source.
let
  appId = "com.ayugram.desktop";
  wrapped = mkNixPak {
    config =
      { sloth, ... }:
      {
        imports = [
          ./modules/gui-base.nix
          ./modules/network.nix
          ./modules/common.nix
        ];
        app.package = ayugramDesktop;
        flatpak.appId = appId;

        dbus = {
          enable = true;
          policies = {
            "com.canonical.indicator.application" = "talk";
            "org.ayatana.indicator.application" = "talk";
            "org.sigxcpu.Feedback" = "talk";
          };
        };

        bubblewrap = {
          bind.rw = [
            sloth.xdgDocumentsDir
            sloth.xdgDownloadDir
            sloth.xdgMusicDir
            sloth.xdgVideosDir
            sloth.xdgPicturesDir
          ];
          sockets = {
            x11 = false;
            wayland = true;
            pipewire = true;
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
      desktopName = "AyuGram";
      comment = "AyuGram Desktop — Telegram fork with privacy extensions";
      tryExec = exePath;
      exec = "${exePath} -- %u";
      # Best-effort icon path (common hicolor layout). If the desktop
      # menu shows a blank icon, look up the real path with:
      #   find $(nix build --print-out-paths '.#packages.x86_64-linux.ayugram-desktop' --no-link) \
      #     -name '*.png' -o -name '*.svg'
      icon = "${ayugramDesktop}/share/icons/hicolor/256x256/apps/ayugram-desktop.png";
      startupNotify = true;
      startupWMClass = appId;
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
      ];
      keywords = [
        "tg"
        "chat"
        "im"
        "messaging"
        "ayugram"
        "tdesktop"
      ];
      extraConfig.X-Flatpak = appId;
    })
  ];
}
