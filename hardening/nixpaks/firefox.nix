# Refer:
# - Flatpak manifest's docs:
#   - https://docs.flatpak.org/en/latest/manifests.html
#   - https://docs.flatpak.org/en/latest/sandbox-permissions.html
# - Firefox's flatpak manifest: https://hg.mozilla.org/mozilla-central/file/tip/taskcluster/docker/firefox-flatpak/runme.sh#l151
{
  lib,
  pkgs,
  firefox,
  mkNixPak,
  buildEnv,
  makeDesktopItem,
  ...
}:

let
  appId = "org.mozilla.firefox";

  # The site sends Content-Disposition filenames as bare GBK bytes instead of
  # RFC 5987 `filename*=UTF-8''...`, which Firefox otherwise stores mojibake.
  # AMO signs and resigns this XPI; keep the URL and hash in sync with the
  # add-on API when updating.
  downloadFilenameEncoding = pkgs.fetchurl {
    name = "download-filename-encoding.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4272940/download_filename_encoding-2.1resigned1.xpi";
    sha256 = "f1c80d7c41305a3b05b2022876827006795d2a72beaa478f2f2d56467fd9c3d2";
  };

  bitwardenPasswordManager = pkgs.fetchurl {
    name = "bitwarden-password-manager.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4970633/bitwarden_password_manager-2026.8.0.xpi";
    sha256 = "989ee33f19329af1fc155dcebb7f90a517a7259cea4bfbdd660923d25a7d465a";
  };

  immersiveTranslate = pkgs.fetchurl {
    name = "immersive-translate.xpi";
    url = "https://addons.mozilla.org/firefox/downloads/file/4844745/immersive_translate-1.30.2.xpi";
    sha256 = "8b07a51726911e225b3fbb3a08c0c7861d1a5ce95fcfc2ae30de0252f189e2fd";
  };

  # Wrap the raw Firefox install first: wrapFirefox needs a real unwrapped
  # package, not a symlinkJoin, or the wrapper script would still launch the
  # original store path and none of the policies/prefs below would be read.
  firefoxWithPolicy = pkgs.wrapFirefox firefox.unwrapped {
    extraPolicies = {
      Certificates.Install = [
        "/app/etc/firefox/certs/mkcert-rootCA.pem"
      ];
      # Install the signed AMO XPI via enterprise policy; this is the same
      # mechanism wrapFirefox uses for Nix-declared extensions.
      Extensions.Install = [
        "${downloadFilenameEncoding}"
        "${bitwardenPasswordManager}"
        "${immersiveTranslate}"
      ];
      ExtensionSettings = {
        "download-filename-encoding@qw.linux-2g64.local" = {
          installation_mode = "allowed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "allowed";
        };
        "{5efceaa7-f3a2-4e59-a54b-85319448e305}" = {
          installation_mode = "allowed";
        };
      };
    };
    # Firefox detects `/.flatpak-info` and takes the xdg-desktop-portal
    # OpenDirectory path for "Show in Folder". nixpak exposes FileManager1
    # directly and Dolphin handles ShowItems reliably, so prefer that route.
    extraPrefs = ''
      pref("widget.use-xdg-desktop-portal.open-uri", 0);
    '';
  };

  # Ship the mkcert root CA inside the sandboxed Firefox install dir and have
  # the enterprise policy install it into every profile, so the local HTTPS
  # certificates stay trusted after profile resets or re-provisioning.
  firefoxWithCa = pkgs.symlinkJoin {
    name = "firefox-with-mkcert-ca";
    paths = [ firefoxWithPolicy ];
    meta = firefoxWithPolicy.meta;
    postBuild = ''
      mkdir -p "$out/lib/firefox/certs"
      cp ${../../certs/https/mkcert-rootCA.pem} "$out/lib/firefox/certs/mkcert-rootCA.pem"
    '';
  };

  wrapped = mkNixPak {
    config =
      {
        config,
        sloth,
        ...
      }:
      {
        app = {
          package = firefoxWithCa;
          binPath = "bin/firefox";
        };
        flatpak.appId = appId;

        imports = [
          ./modules/gui-base.nix
          ./modules/network.nix
          ./modules/common.nix
        ];

        bubblewrap = {
          bind.rw = [
            # given the read write permission to the following directories.
            # NOTE: sloth.mkdir is used to create the directory if it does not exist!
            (sloth.mkdir (sloth.concat' sloth.homeDir "/.mozilla"))

            sloth.xdgDocumentsDir
            sloth.xdgDownloadDir
            sloth.xdgMusicDir
            sloth.xdgVideosDir
            sloth.xdgPicturesDir
          ];
          bind.ro = [
            "/sys/bus/pci"
            [
              "${config.app.package}/lib/firefox"
              "/app/etc/firefox"
            ]

            # ================ for browserpass extension ===============================
            "/etc/gnupg"
            (sloth.concat' sloth.homeDir "/.gnupg") # gpg's config
            (sloth.concat' sloth.homeDir "/.local/share/password-store") # my secrets
            (sloth.concat' sloth.runtimeDir "/gnupg") # for access gpg-agent socket

            # Firefox falls back to a localized download folder name when it
            # cannot read the host XDG user dirs; the real folder is Downloads.
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.dirs")
            (sloth.concat' sloth.xdgConfigHome "/user-dirs.locale")

            # Unsure
            (sloth.concat' sloth.xdgConfigHome "/dconf")
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
      desktopName = "Firefox";
      genericName = "Firefox Boxed";
      comment = "Firefox Browser";
      exec = "${exePath} %U";
      terminal = false;
      # Absolute path into the upstream firefox package — buildEnv only
      # links the wrapper script + .desktop file, so a bare `firefox`
      # icon name would not resolve. `Icon=` accepts full paths per the
      # desktop-entry spec.
      icon = "${firefox}/share/icons/hicolor/128x128/apps/firefox.png";
      startupNotify = true;
      startupWMClass = "firefox";
      type = "Application";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeTypes = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];

      actions = {
        new-private-window = {
          name = "New Private Window";
          exec = "${exePath} --private-window %U";
        };
        new-window = {
          name = "New Window";
          exec = "${exePath} --new-window %U";
        };
        profile-manager-window = {
          name = "Profile Manager";
          exec = "${exePath} --ProfileManager";
        };
      };

      extraConfig = {
        X-Flatpak = appId;
      };
    })
  ];
}
