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

  # QQ's Linux screenshot path is X11-only: wrapper.node calls XOpenDisplay and
  # then XGetImage.  Under Wayland that lands on XWayland, where XGetImage fails
  # with BadMatch -- and Xlib's *default* error handler prints the error and
  # calls exit(1), so QQ's own "did it return NULL?" fallback never runs and the
  # whole client dies.  (Observed: "X Error of failed request: BadMatch /
  # Major opcode of failed request: 73 (X_GetImage)".)
  #
  # The fix is to install an error handler that swallows exactly that one
  # failure: XGetImage then returns NULL and QQ falls through to its own
  # "screenshot unsupported" path instead of aborting.  Every other X error is
  # forwarded to the handler Xlib had installed.
  #
  # Note we deliberately do *not* make XOpenDisplay fail: QQ also uses its X11
  # connection for clipboard integration, which needs the connection to work.
  qqShim =
    pkgs.runCommand "qq-shim"
      {
        nativeBuildInputs = [
          pkgs.gcc
          pkgs.libx11
        ];
      }
      ''
        mkdir -p $out/lib
        cat > qq-shim.c <<'EOF'
        #define _GNU_SOURCE
        #include <dlfcn.h>
        #include <stddef.h>
        #include <X11/Xlib.h>

        /* From X11/X.h: BadMatch is error code 8, and the X_GetImage request
           has major opcode 73. */
        #define QQ_BAD_MATCH 8
        #define QQ_X_GET_IMAGE 73

        typedef Display *(*XOpenDisplay_fn)(const char *);
        typedef XErrorHandler (*XSetErrorHandler_fn)(XErrorHandler);

        static XOpenDisplay_fn real_XOpenDisplay;
        static XSetErrorHandler_fn real_XSetErrorHandler;
        static XErrorHandler prev_error_handler;

        static int qq_x_error_handler(Display *dpy, XErrorEvent *ev) {
          /* Swallow the screenshot failure only.  Returning 0 keeps Xlib from
             unwinding; the pending XGetImage then yields NULL. */
          if (ev->request_code == QQ_X_GET_IMAGE && ev->error_code == QQ_BAD_MATCH)
            return 0;
          if (prev_error_handler != NULL)
            return prev_error_handler(dpy, ev);
          return 0;
        }

        __attribute__((constructor))
        static void qq_shim_init(void) {
          real_XOpenDisplay = (XOpenDisplay_fn)dlsym(RTLD_NEXT, "XOpenDisplay");
          real_XSetErrorHandler = (XSetErrorHandler_fn)dlsym(RTLD_NEXT, "XSetErrorHandler");
        }

        /* Open the display normally -- clipboard integration depends on it --
           and attach the handler that makes screenshots non-fatal. */
        Display *XOpenDisplay(const char *name) {
          Display *dpy;

          if (real_XOpenDisplay == NULL)
            real_XOpenDisplay = (XOpenDisplay_fn)dlsym(RTLD_NEXT, "XOpenDisplay");
          if (real_XOpenDisplay == NULL)
            return NULL;

          dpy = real_XOpenDisplay(name);
          if (dpy != NULL && real_XSetErrorHandler != NULL && prev_error_handler == NULL)
            prev_error_handler = real_XSetErrorHandler(qq_x_error_handler);
          return dpy;
        }
        EOF
        gcc -shared -fPIC -O2 -Wall -o $out/lib/qq-shim.so qq-shim.c -ldl -lX11
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
            # Keep the X11 socket bound: QQ probes it for clipboard and tray
            # integration.  The screenshot crash is handled by the XOpenDisplay
            # shim above, which makes QQ see no X server regardless of what is
            # actually bound here.
            x11 = true;
            wayland = true;
            pipewire = true;
          };
          env = {
            QT_QPA_PLATFORM = "wayland;xcb";
            NIXOS_OZONE_WL = "1";
            # Make the X11 screenshot failure non-fatal; see the shim above.
            LD_PRELOAD = "${qqShim}/lib/qq-shim.so";
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
