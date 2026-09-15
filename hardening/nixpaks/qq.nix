{
  lib,
  pkgs,
  qq,
  buildEnv,
  mkNixPak,
  makeDesktopItem,
  ...
}:
let
  appId = "com.qq.QQ";

  # GTK needs an immodules cache to find fcitx5's IM module inside the sandbox.
  gtk3Cache =
    pkgs.runCommand "gtk3-immodule.cache"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        nativeBuildInputs = [
          pkgs.gtk3
          pkgs.fcitx5-gtk
        ];
      }
      ''
        mkdir -p $out/etc/gtk-3.0
        GTK_PATH=${pkgs.fcitx5-gtk}/lib/gtk-3.0 \
          ${pkgs.gtk3.dev}/bin/gtk-query-immodules-3.0 > $out/etc/gtk-3.0/immodules.cache
      '';

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
            x11 = true;
            wayland = lib.mkForce false;
            pipewire = true;
          };
          env = {
            # QQ is Electron running under XWayland; fcitx5 needs these
            # legacy IM variables to attach to the input context.
            QT_QPA_PLATFORM = "xcb";
            QT_IM_MODULE = "fcitx";
            GTK_IM_MODULE = "fcitx";
            GTK_PATH = "${pkgs.fcitx5-gtk}/lib/gtk-3.0";
            GTK_IM_MODULE_FILE = "${gtk3Cache}/etc/gtk-3.0/immodules.cache";
            XMODIFIERS = "@im=fcitx";
          };
        };
      };
  };
  # niri's XWayland Satellite does not export XAUTHORITY, while the nixpak
  # launcher requires it whenever the X11 socket is enabled. Keep the fallback
  # scoped to QQ so Plasma sessions with a real Xauthority still use theirs.
  qqWrapper = pkgs.writeShellScriptBin "qq" ''
    export XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}"
    exec ${wrapped.config.script}/bin/qq "$@"
  '';
  exePath = lib.getExe qqWrapper;
in
buildEnv {
  inherit (wrapped.config.script) name meta passthru;
  paths = [
    qqWrapper
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
