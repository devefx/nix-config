{
  config,
  lib,
  pkgs,
  wallpapers,
  ...
}:
let
  # Noctalia normally re-runs ddcutil whenever the monitor list or bus changes.
  # This YCT USB-C display resets its hub on DDC queries, so only initialize DDC
  # once per Noctalia session and never re-query after blanking or reconnecting.
  noctaliaShell = pkgs.noctalia-shell.overrideAttrs (old: {
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
  home.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
  };

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
