{
  lib,
  pkgs,
}:

# OpenAI ships Codex/ChatGPT desktop as a Debian package. NixOS cannot use
# dpkg state directly, so this wrapper extracts the official .deb and runs it
# inside an FHS environment with the Electron runtime libraries it needs.
let
  version = "26.908.40834";

  src = pkgs.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    sha256 = "sha256-2je457zvquoBnEeMrL5sc+4d3RXg4euzx+8KQt2BisI=";
  };

  chatgpt-files = pkgs.stdenv.mkDerivation {
    pname = "chatgpt";
    inherit version src;

    nativeBuildInputs = [ pkgs.dpkg ];

    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      unpack_dir="$TMPDIR/unpacked"
      mkdir -p "$unpack_dir" "$out/bin" "$out/lib" "$out/share"
      dpkg-deb -x "$src" "$unpack_dir"
      cp -a "$unpack_dir/usr/bin/." "$out/bin/"
      cp -a "$unpack_dir/usr/lib/chatgpt" "$out/lib/chatgpt"
      cp -a "$unpack_dir/usr/share/applications/." "$out/share/applications/"
      cp -a "$unpack_dir/usr/share/pixmaps/." "$out/share/pixmaps/"
      install -Dm0644 "$unpack_dir/usr/share/pixmaps/chatgpt.png" \
        "$out/share/icons/hicolor/256x256/apps/chatgpt.png"
      runHook postInstall
    '';
  };

  fhs = pkgs.buildFHSEnv {
    name = "chatgpt";

    targetPkgs =
      p:
      [
        chatgpt-files
      ]
      ++ (with p; [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        cairo
        cups
        dbus
        expat
        gdk-pixbuf
        glib
        graphite2
        gsettings-desktop-schemas
        gtk3
        libX11
        libXScrnSaver
        libXcomposite
        libXcursor
        libXdamage
        libXext
        libXfixes
        libXi
        libXrandr
        libXtst
        libdrm
        libgbm
        libglvnd
        libnotify
        libusb1
        libxcb
        libxkbcommon
        mesa
        nspr
        nss
        openssl
        pango
        pipewire
        stdenv.cc.cc.lib
        systemd
        wayland
        xz
        zlib
        zstd
      ]);

    runScript = "chatgpt";
  };

  # The desktop app is single-instance. Reuse a live instance by activating
  # its window, and only clear SingletonLock state when its owner has exited.
  chatgptWrapper = pkgs.writeShellApplication {
    name = "chatgpt";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      kdotool
      niri
    ];
    text = ''
      config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
      profile_dir="$config_home/Codex"
      lock_path="$profile_dir/SingletonLock"

      focus_niri_window() {
        [ -n "''${NIRI_SOCKET:-}" ] && [ -S "$NIRI_SOCKET" ] || return 1

        local window_id
        window_id="$(
          niri msg --json windows 2>/dev/null |
            jq -r '[.[] | select((((.app_id // "") + " " + (.title // "")) | ascii_downcase | contains("chatgpt")))] | first | .id // empty' 2>/dev/null
        )" || return 1

        [ -n "$window_id" ] || return 1
        niri msg action focus-window --id "$window_id" >/dev/null 2>&1
      }

      focus_kde_window() {
        case "''${KDE_FULL_SESSION:-}:''${XDG_CURRENT_DESKTOP:-}" in
          true:* | *:KDE | *:Plasma) ;;
          *) return 1 ;;
        esac

        local window_id
        window_id="$(kdotool search --class '^[Cc]hatgpt$' 2>/dev/null | head -n 1)" || return 1

        [ -n "$window_id" ] || return 1
        kdotool windowactivate "$window_id" >/dev/null 2>&1
      }

      focus_existing_window() {
        focus_niri_window || focus_kde_window
      }

      focus_backend_available() {
        [ -n "''${NIRI_SOCKET:-}" ] && [ -S "$NIRI_SOCKET" ] && return 0

        case "''${KDE_FULL_SESSION:-}:''${XDG_CURRENT_DESKTOP:-}" in
          true:* | *:KDE | *:Plasma) return 0 ;;
          *) return 1 ;;
        esac
      }

      if focus_existing_window; then
        exit 0
      fi

      lock_target=""
      lock_pid=""
      if [ -L "$lock_path" ]; then
        lock_target="$(readlink "$lock_path" 2>/dev/null || true)"
        lock_pid="''${lock_target##*-}"
      fi

      is_chatgpt_pid() {
        [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null || return 1

        executable="$(readlink "/proc/$lock_pid/exe" 2>/dev/null || true)"
        command_name="$(cat "/proc/$lock_pid/comm" 2>/dev/null || true)"
        case "$executable $command_name" in
          *ChatGPT*) return 0 ;;
          *) return 1 ;;
        esac
      }

      # A fresh launch can take several seconds to map its window. Wait for a
      # live instance to become focusable, but never terminate it.
      if is_chatgpt_pid; then
        if focus_backend_available; then
          for _ in $(seq 1 16); do
            if focus_existing_window; then
              exit 0
            fi
            sleep 0.5
          done
        fi
      else
        # Chromium may leave these symlinks pointing at an exited process.
        rm -f \
          "$profile_dir/SingletonLock" \
          "$profile_dir/SingletonSocket" \
          "$profile_dir/SingletonCookie"
      fi

      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      log_dir="$state_home/chatgpt"
      log_file="$log_dir/desktop.log"
      mkdir -p "$log_dir"
      if [ -f "$log_file" ] && [ "$(wc -c < "$log_file")" -gt 1048576 ]; then
        mv -f "$log_file" "$log_file.old"
      fi

      exec ${fhs}/bin/chatgpt "$@" >>"$log_file" 2>&1
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "chatgpt";
    desktopName = "ChatGPT";
    comment = "ChatGPT by OpenAI";
    icon = "chatgpt";
    exec = "${lib.getExe chatgptWrapper} %U";
    startupWMClass = "Chatgpt";
    categories = [
      "Development"
    ];
    mimeTypes = [
      "x-scheme-handler/codex"
    ];
  };

  icon = pkgs.runCommand "chatgpt-icons" { } ''
    mkdir -p "$out/share/icons/hicolor/256x256/apps"
    cp "${chatgpt-files}/share/icons/hicolor/256x256/apps/chatgpt.png" \
      "$out/share/icons/hicolor/256x256/apps/chatgpt.png"
  '';
in
pkgs.buildEnv {
  name = "chatgpt-desktop";
  paths = [
    chatgptWrapper
    desktopItem
    icon
  ];

  meta = {
    description = "Codex/ChatGPT desktop app from OpenAI's official Linux .deb";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
