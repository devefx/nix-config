{
  lib,
  pkgs,
  config,
  ...
}:
# Android export environment for the local Godot yoke branch, following:
# https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
#
# Provides JDK 17, adb, and a Nix-composed Android SDK. Versions are taken
# from the branch's `platform/android/java/app/config.gradle`:
#   - platform-tools 37.0.1
#   - build-tools 36.1.0
#   - platform android-36
#   - cmdline-tools latest
#   - cmake 3.10.2.4988404
#   - NDK 29.0.14206865
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.godotAndroid;

  androidEnv = pkgs.androidenv.override { licenseAccepted = true; };

  androidSdk =
    (androidEnv.composeAndroidPackages {
      includeNDK = true;
      ndkVersion = "29.0.14206865";
      platformVersions = [ "36" ];
      buildToolsVersions = [ "36.1.0" ];
      platformToolsVersion = "37.0.1";
      cmdLineToolsVersion = "latest";
      includeCmake = true;
      cmakeVersions = [ "3.10.2" ];
    }).androidsdk;

  jdk = pkgs.openjdk17;

  androidSdkPath = "${androidSdk}/libexec/android-sdk";
in
{
  options.modules.godotAndroid = {
    enable = mkEnableOption "Godot Android export environment (JDK, Android SDK, NDK)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      androidSdk
      jdk
      pkgs.android-tools # adb / fastboot
    ];

    home.sessionVariables = {
      ANDROID_HOME = androidSdkPath;
      ANDROID_SDK_ROOT = androidSdkPath;
      JAVA_HOME = jdk.home;
    };

    # Godot's exporter reads these paths from Editor Settings, not only from
    # environment variables, so keep the 4.7 settings file in sync.
    home.activation.updateGodotAndroidSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="${config.home.homeDirectory}/.config/godot/editor_settings-4.7.tres"
      mkdir -p "$(dirname "$settings")"
      touch "$settings"

      if grep -q '^export/android/java_sdk_path' "$settings"; then
        sed -i "s|^export/android/java_sdk_path = .*|export/android/java_sdk_path = \"${jdk.home}\"|" "$settings"
      else
        printf '\nexport/android/java_sdk_path = "%s"\n' "${jdk.home}" >> "$settings"
      fi

      if grep -q '^export/android/android_sdk_path' "$settings"; then
        sed -i "s|^export/android/android_sdk_path = .*|export/android/android_sdk_path = \"${androidSdkPath}\"|" "$settings"
      else
        printf '\nexport/android/android_sdk_path = "%s"\n' "${androidSdkPath}" >> "$settings"
      fi
    '';
  };
}
