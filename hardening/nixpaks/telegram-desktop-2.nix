{
  lib,
  telegram-desktop,
  buildEnv,
  mkNixPak,
  makeDesktopItem,
  runCommandLocal,
  writeShellScriptBin,
  ...
}:
# Second instance of the official Telegram Desktop, so two accounts can be online at once.
# Same upstream derivation as ./telegram-desktop.nix; only the identity differs.
#
# appId is load-bearing beyond naming: it selects ~/.var/app/<appId>/{data,config,cache},
# the <appId>.desktop file, the D-Bus and portal policies in ./modules/common.nix, and
# org.mpris.MediaPlayer2.<last segment of appId>. That last one is why this is
# org.telegram.desktop2 rather than org.telegram.desktop.Second: the segment after the
# final dot must not be "desktop", or the two instances fight over one MPRIS name.
#
# WM_CLASS stays "TelegramDesktop" (hardcoded in tdesktop), so niri window rules and the
# task switcher see a single window class for both instances; separating them needs a
# window-title rule.
let
  appId = "org.telegram.desktop2";

  # appId isolation alone does not make double-launch work; this wrapper is what does.
  #
  # tdesktop's single-instance lock is a Linux *abstract* socket named by a hash of its
  # working dir (@<hash>-TelegramDesktop in `ss -xl`). Abstract sockets are scoped only by
  # network namespace, and this sandbox shares the host one: ./modules/network.nix sets
  # bubblewrap.network while pasta is off, so nixpak's launch.nix emits --unshare-net and
  # then undoes it with --share-net. Each sandbox also binds its own data dir to the same
  # in-sandbox path $HOME/.local/share, so both instances compute the same socket name and
  # a second launch only raises the first window and exits by itself:
  #   Socket connected, this is not the first application instance, sending show command...
  #
  # -workdir breaks the tie (two listeners, two live processes -- verified). It is injected
  # here because the path must be expanded inside the sandbox (.desktop Exec fields are not
  # shell-expanded), and nixpak's bind covers that path, so tdata/ and the login persist at
  # ~/.var/app/org.telegram.desktop2/data/TelegramDesktop2/.
  #
  # Telegram2 rather than Telegram because nixpak puts its launcher at
  # $out/bin/<meta.mainProgram of app.package>, so reusing the name would collide with
  # pkgs.nixpaks.telegram-desktop in the home profile. The real binary is still exec'd as
  # Telegram, so argv[0], WM_CLASS and the process name are unchanged.
  appExe = writeShellScriptBin "Telegram2" ''
    exec ${telegram-desktop}/bin/Telegram -workdir "$HOME/.local/share/TelegramDesktop2" "$@"
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
        app.package = appExe;
        flatpak.appId = appId;

        # Same as the first instance: tray indicators and libfeedback.
        dbus = {
          enable = true;
          policies = {
            "com.canonical.indicator.application" = "talk";
            "org.ayatana.indicator.application" = "talk";
            "org.sigxcpu.Feedback" = "talk";
          };
        };

        bubblewrap = {
          # Send / receive files only through the standard XDG user dirs.
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

  # desktopFileName is now org.telegram.desktop2 while upstream only ships icons named
  # org.telegram.desktop, so this instance's tray and notification icons would resolve to
  # nothing. Add only the aliased file, at every size upstream ships: copying the originals
  # as well would risk colliding with another package's hicolor tree in the home profile.
  hicolorIcons = runCommandLocal "telegram-desktop-2-icons" { } ''
    mkdir -p $out/share/icons/hicolor
    ( cd ${telegram-desktop}/share/icons/hicolor && find . -type f \
      \( -name "org.telegram.desktop.png" -o -name "org.telegram.desktop.svg" \) \
    ) | while read -r rel; do
      dir=$(dirname "$out/share/icons/hicolor/$rel")
      base=$(basename "$rel")
      mkdir -p "$dir"
      cp "${telegram-desktop}/share/icons/hicolor/$rel" "$dir/''${base%.*}2.''${base##*.}"
    done
  '';

  exePath = lib.getExe wrapped.config.script;
in
buildEnv {
  inherit (wrapped.config.script) name meta passthru;
  paths = [
    wrapped.config.script
    hicolorIcons
    (makeDesktopItem {
      name = appId;
      desktopName = "Telegram 2";
      comment = "Telegram Desktop, second instance (separate account and data dir)";
      tryExec = "${exePath}";
      exec = "${exePath} -- %u";
      # Absolute path: buildEnv ships only the wrapper script, the icon alias and this
      # entry, so a bare icon name would not resolve. Same pattern as ./telegram-desktop.nix.
      icon = "${telegram-desktop}/share/icons/hicolor/256x256/apps/org.telegram.desktop.png";
      startupNotify = true;
      startupWMClass = "TelegramDesktop";
      terminal = false;
      type = "Application";
      categories = [
        "Chat"
        "Network"
        "InstantMessaging"
        "Qt"
      ];
      mimeTypes = [ "x-scheme-handler/tg" ];
      keywords = [
        "tg"
        "chat"
        "im"
        "messaging"
        "messenger"
        "tdesktop"
        "second"
        "dual"
        "alt"
      ];
      actions.quit = {
        name = "Quit Telegram 2";
        exec = "${exePath} -quit";
        icon = "application-exit";
      };
      # No DBusActivatable: the sandbox ships no matching service file, so KDE's activation
      # path fails with "name is not activatable" and must fall back to Exec=. Both
      # instances declare tg://; whichever registers first wins as the scheme handler.
      extraConfig = {
        X-Flatpak = appId;
        SingleMainWindow = "true";
        X-GNOME-UsesNotifications = "true";
        X-GNOME-SingleWindow = "true";
      };
    })
  ];
}
