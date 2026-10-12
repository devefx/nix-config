{
  config,
  lib,
  pkgs,
  wallpapers,
  ...
}:
let
  # Quickshell draws the system tray with QIcon::fromTheme(), and Qt only
  # consults the desktop icon theme when a QPA platform theme plugin is loaded.
  # Without one, Qt falls back to a hicolor-only lookup, so every tray glyph
  # that only lives in breeze/papirus fails to load and Quickshell paints its
  # magenta/black missing-icon checkerboard instead:
  #
  #   input-keyboard-symbolic  fcitx5 while the English layout is active
  #   user-desktop             ActiveWindow widget's fallback icon
  #   application-x-executable launcher/audio-panel fallback icon
  #
  # Setting QT_QPA_PLATFORMTHEME=qt6ct (done in niri's config.kdl) is not enough
  # on its own: the qt6ct plugin has to be discoverable too. Injecting it into
  # the wrapper here keeps it scoped to the one app that needs it, instead of
  # putting qt6ct's plugin dir in front of every Qt app niri spawns. niri's
  # `environment` block is also only read at config load, so a wrapper-level
  # setting does not need a session restart to take effect.
  #
  # Qt6 does not consult QT_STYLE_OVERRIDE in order to pick up a style plugin,
  # so only the platformtheme plugin is added here. qt6ct.conf's
  # style=Fusion is already the qt6ct default.
  #
  # qt6ct.conf also carries icon_theme=breeze-dark, which is what makes the
  # lookup above succeed *and* keeps the glyphs legible: the Breeze SVGs use
  # `fill:currentColor` with a hardcoded dark .ColorScheme-Text, so the light
  # "breeze" theme rasterises to rgb(35,37,41) and vanishes against the #111416
  # bar. The tray colorize shader cannot rescue that either -- see qt6ct.conf.
  #
  # Must be a single --prefix for the whole variable. qt6ct is deliberately not
  # in buildInputs: qtHostPathHook would then append the same plugin dir again,
  # and makeWrapper silently drops the earlier value when one variable is given
  # more than one --prefix.

  # Noctalia normally re-runs ddcutil whenever the monitor list or bus changes.
  # This YCT USB-C display resets its hub on DDC queries, so only initialize DDC
  # once per Noctalia session and never re-query after blanking or reconnecting.
  noctaliaShell = pkgs.noctalia-shell.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      wrapProgram $out/bin/noctalia-shell \
        --prefix QT_PLUGIN_PATH : ${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins
    '';

    patches = (old.patches or [ ]) ++ [
      (pkgs.writeText "noctalia-no-ddc-reinit.patch" ''
        --- a/Services/Hardware/BrightnessService.qml
        +++ b/Services/Hardware/BrightnessService.qml
        @@ -9,6 +9,8 @@
           id: root

           property list<var> ddcMonitors: []
        +  property var ddcBrightnessByConnector: ({})
        +  property bool ddcInitialized: false
           readonly property list<Monitor> monitors: variants.instances
           property bool appleDisplayPresent: false
           property list<var> availableBacklightDevices: []
        @@ -157,9 +159,8 @@
           }

           onMonitorsChanged: {
        -    ddcMonitors = [];
             scanBacklightDevices();
        -    if (Settings.data.brightness.enableDdcSupport) {
        +    if (Settings.data.brightness.enableDdcSupport && !root.ddcInitialized) {
               ddcProc.running = true;
             }
           }
        @@ -170,10 +171,12 @@
               if (Settings.data.brightness.enableDdcSupport) {
                 // Re-detect DDC monitors when enabled
                 ddcMonitors = [];
        +        root.ddcInitialized = false;
                 ddcProc.running = true;
               } else {
                 // Clear DDC monitors when disabled
                 ddcMonitors = [];
        +        root.ddcInitialized = false;
               }
             }
             function onBacklightDeviceMappingsChanged() {
        @@ -255,6 +258,7 @@
                                                      };
                                                    });
                 root.ddcMonitors = ddcProc.ddcMonitors.filter(m => m.isDdc);
        +        root.ddcInitialized = true;
               }
             }
           }
        @@ -278,7 +282,7 @@
               return brightnessPath !== "";
             }

        -    property real brightness
        +    property real brightness: root.ddcBrightnessByConnector[modelData.name] ?? 0
             property real lastBrightness: 0
             property real queuedBrightness: NaN
             property bool commandRunning: false
        @@ -320,6 +324,7 @@
                       if (!isNaN(current) && !isNaN(max) && max > 0) {
                         monitor.maxBrightness = max;
                         newBrightness = current / max;
        +                root.ddcBrightnessByConnector[monitor.modelData.name] = newBrightness;
                       }
                     }
                   } else {
        @@ -415,6 +420,7 @@
                       if (!isNaN(current) && !isNaN(max) && max > 0) {
                         monitor.maxBrightness = max;
                         monitor.brightness = current / max;
        +                root.ddcBrightnessByConnector[monitor.modelData.name] = monitor.brightness;
                         Logger.d("Brightness", "DDC brightness:", current + "/" + max + " =", monitor.brightness);
                       }
                     }
        @@ -484,6 +490,8 @@

               // Always update internal value and trigger UI feedback immediately
               monitor.brightness = value;
        +      if (isDdc)
        +        root.ddcBrightnessByConnector[monitor.modelData.name] = value;
               monitor.brightnessUpdated(value);
               root.monitorBrightnessChanged(monitor, monitor.brightness);

        @@ -550,6 +558,9 @@

             onBusNumChanged: initBrightness()
             onIsDdcChanged: initBrightness()
        -    Component.onCompleted: initBrightness()
        +    Component.onCompleted: {
        +      if (!monitor.isDdc || !root.ddcInitialized)
        +        initBrightness();
        +    }
           }
         }
      '')
    ];
  });
in
lib.mkIf config.modules.desktop.niri.enable {
  # No `home.sessionVariables` here, deliberately. Home Manager writes those to
  # $profile/etc/profile.d/hm-session-vars.sh, and nothing in this session
  # sources that file: niri.service execs `niri --session` directly so no login
  # shell runs, and /etc/static/profile has no profile.d loop either. Measured:
  # niri's own environment contains no QT_* variable at all, which is why
  # QT_QPA_PLATFORM / QT_QPA_PLATFORMTHEME / QT_AUTO_SCREEN_SCALE_FACTOR used to
  # sit here without ever taking effect.
  #
  # Settings that must actually reach niri's children belong in the
  # `environment` block of conf/config.kdl, where QT_QPA_PLATFORMTHEME=qt6ct now
  # lives. `wayland;xcb` is dropped rather than moved because it is already Qt's
  # own platform fallback order, and the qt6ct plugin needs the wrapper
  # injection below regardless of which platform is picked.

  home.packages = [
    noctaliaShell
    pkgs.kdePackages.breeze-icons
    pkgs.qt6Packages.qt6ct
    pkgs.papirus-icon-theme
    pkgs.app2unit
    pkgs.wlsunset
    pkgs.xrdb
  ]
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    pkgs.gpu-screen-recorder
  ];

  # ChatGPT runs through XWayland on this scaled output. Fcitx's XCB input
  # panel otherwise uses 96 DPI and renders smaller than native Wayland apps.
  xresources.properties."Xft.dpi" = 192;

  home.file."Pictures/Wallpapers".source = wallpapers;

  xdg.configFile = {
    # Keep ~/.config/noctalia as a real directory so Noctalia can generate
    # colors.json and other runtime state alongside the declarative files.
    "noctalia/settings.json".source = ./noctalia/config/settings.json;
    "noctalia/plugins.json".source = ./noctalia/config/plugins.json;
    "qt6ct/qt6ct.conf".source = ./noctalia/qt6ct.conf;
  };
}
