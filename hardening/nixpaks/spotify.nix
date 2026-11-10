{
  lib,
  pkgs,
  buildEnv,
  mkNixPak,
  makeDesktopItem,
  ...
}:
let
  appId = "com.spotify.Client";

  wrapped = mkNixPak {
    config =
      { ... }:
      {
        imports = [
          ./modules/gui-base.nix
          ./modules/network.nix
          ./modules/common.nix
        ];
        app = {
          package = pkgs.spotify;
          binPath = "bin/spotify";
        };
        flatpak.appId = appId;

        dbus.policies = {
          # Spotify registers MPRIS under the bare "spotify" name, not the
          # flatpak app id that modules/common.nix derives from.
          "org.mpris.MediaPlayer2.spotify" = "own";
          "org.mpris.MediaPlayer2.spotify.*" = "own";
        };

        bubblewrap = {
          sockets = {
            # X11 by default: windowrules.kdl and the xwayland-satellite patch
            # are keyed on the X11 WM_CLASS ("Spotify"). The Wayland socket is
            # bound as well so NIXOS_OZONE_WL=1 still works if wanted.
            x11 = true;
            wayland = true;
            pipewire = true;
          };
        };
      };
  };

  # niri's XWayland satellite does not export XAUTHORITY, while the nixpak
  # launcher requires it whenever the X11 socket is bound. Keep the fallback
  # scoped to Spotify.
  spotifyWrapper = pkgs.writeShellScriptBin "spotify" ''
    export XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}"
    exec ${wrapped.config.script}/bin/spotify "$@"
  '';

  exePath = lib.getExe spotifyWrapper;
in
buildEnv {
  inherit (wrapped.config.script) name meta passthru;
  paths = [
    spotifyWrapper
    (makeDesktopItem {
      name = appId;
      desktopName = "Spotify";
      genericName = "Spotify Boxed";
      comment = "Spotify music streaming";
      tryExec = exePath;
      exec = "${exePath} %U";
      icon = "${pkgs.spotify}/share/icons/hicolor/512x512/apps/spotify-client.png";
      startupNotify = true;
      startupWMClass = "Spotify";
      terminal = false;
      type = "Application";
      categories = [
        "Audio"
        "Music"
        "Player"
      ];
      extraConfig = {
        X-Flatpak = appId;
      };
    })
  ];
}
