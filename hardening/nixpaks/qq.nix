{
  lib,
  qq,
  buildEnv,
  mkNixPak,
  makeDesktopItem,
  ...
}:
let
  appId = "com.qq.QQ";
  wrapped = mkNixPak {
    config =
      { sloth, ... }:
      {
        imports = [
          ./modules/gui-base.nix
          ./modules/network.nix
          ./modules/common.nix
        ];
        app = {
          package = qq;
          binPath = "bin/qq";
        };
        flatpak.appId = appId;

        bubblewrap = {
          # Send / receive files only through the standard XDG user dirs —
          # no access to the wider home tree. Chat data lives in the
          # nixpak private data dir (see modules/common.nix).
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
      desktopName = "QQ";
      genericName = "QQ Boxed";
      comment = "Tencent QQ instant messaging";
      tryExec = "${exePath}";
      exec = "${exePath} %U";
      icon = "${qq}/share/icons/hicolor/512x512/apps/qq.png";
      startupNotify = true;
      startupWMClass = "QQ";
      terminal = false;
      type = "Application";
      categories = [
        "InstantMessaging"
        "Network"
      ];
      extraConfig = {
        X-Flatpak = appId;
      };
    })
  ];
}