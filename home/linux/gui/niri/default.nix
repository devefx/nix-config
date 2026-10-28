{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.niri;

  ocrPython = pkgs.python3.withPackages (ps: [ ps.rapidocr-onnxruntime ]);
  ocrScript = pkgs.writeText "screenshot-ocr.py" ''
    import sys

    from rapidocr_onnxruntime import RapidOCR


    def main() -> int:
        if len(sys.argv) != 2:
            print("usage: screenshot-ocr.py IMAGE", file=sys.stderr)
            return 2

        result, _ = RapidOCR()(sys.argv[1])
        if not result:
            return 2

        lines = []
        for box, text, score in result:
            if not text or (score is not None and score < 0.3):
                continue
            lines.append((min(point[1] for point in box), min(point[0] for point in box), text))

        if not lines:
            return 2

        lines.sort(key=lambda item: (item[0], item[1]))
        print("\n".join(text for _, _, text in lines))
        return 0


    if __name__ == "__main__":
        raise SystemExit(main())
  '';

  screenshotOcr = pkgs.writeShellApplication {
    name = "screenshot-ocr";
    runtimeInputs = [
      ocrPython
      pkgs.coreutils
      pkgs.grim
      pkgs.libnotify
      pkgs.slurp
      pkgs.wl-clipboard
    ];
    text = ''
      image="$(mktemp --suffix=.png)"
      trap 'rm -f "$image"' EXIT

      geometry="$(slurp -o -d -F monospace)" || exit 0

      # OCR can take several seconds to initialize. Clear the old clipboard
      # immediately so pasting while OCR runs cannot return a stale result.
      wl-copy --clear >/dev/null 2>&1 || true
      notify-send -a "Screenshot OCR" "截图 OCR" "正在识别，完成后会自动复制" >/dev/null 2>&1 || true

      # Let the slurp overlay disappear before capturing the selected region.
      sleep 0.1
      grim -g "$geometry" "$image"

      if ! text="$(python3 ${ocrScript} "$image")"; then
        notify-send -a "Screenshot OCR" "OCR 失败" "未在所选区域识别到文字" >/dev/null 2>&1 || true
        exit 1
      fi

      printf '%s\n' "$text" | wl-copy
      notify-send -a "Screenshot OCR" "截图 OCR" "识别结果已复制" >/dev/null 2>&1 || true
    '';
  };
in
{
  imports = [ ./noctalia.nix ];

  options.modules.desktop.niri = {
    enable = mkEnableOption "Niri compositor user configuration";

    # The patched noctalia-shell package this session runs, assigned by
    # niri/noctalia.nix. Modules that shell out to the bar (ntfy-voice asks it
    # for the do-not-disturb flag) must use this exact build: Quickshell's IPC
    # client hashes the config path baked into the wrapper, so a different
    # noctalia-shell fails with "No running instances for <path>".
    noctaliaShell = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The patched noctalia-shell package this session runs.";
    };
  };

  config = mkIf cfg.enable {
    home.file = {
      ".face".source = ../../../../assets/avatars/yoke.jpg;
      ".face.icon".source = ../../../../assets/avatars/yoke.jpg;
    };

    home.packages = with pkgs; [
      xwayland-satellite
      grim
      slurp
      satty
      wl-clipboard
      cliphist
      brightnessctl
      playerctl
      xdg-user-dirs
      qimgv # image viewer; imv-wayland can busy-loop after closing windows
      file-roller # archive manager; Nautilus' extract entries call it via gnome-autoar
      # file-roller picks its backend by looking these up in PATH. Without
      # them it falls back to its libarchive code path, which never flags
      # encrypted entries, so "Extract Here" silently fails on encrypted
      # archives instead of prompting for the password.
      _7zz # FrCommand7z: encrypted 7z and zip (7-Zip's own build, not p7zip)
      unzip # fallback for plain zip archives, and a useful CLI on its own
      # FrCommandUnarchiver: the only backend that prompts for encrypted RAR.
      #
      # Known trade-off, kept deliberately: this makes file-roller list RARs
      # with `lsar -j`, and fr-process.c accumulates that output in a way that
      # degrades to O(n^2) (NONBLOCK 16 KiB channel, every line g_list_prepend'ed
      # to a growing list). Archives with thousands of entries therefore peg one
      # CPU core for minutes and appear to hang -- and because file-roller is a
      # single-instance GApplication, the stuck instance also swallows every
      # later "open archive" request. Unfixed upstream as of 44.7. Remove unar
      # to get the old behaviour back (no RAR password prompt, but no hang).
      unar
      screenshotOcr
    ];

    # mpv lives in base/mpv.nix (modules.mpv) now that it ships the
    # akFace/mpv.config tree instead of a handful of inline options.

    # Godot's XWayland game embedding creates an extra wrapper window whose
    # physical size does not line up with niri's logical, scaled layout.
    # Run debug games as regular floating windows instead.
    home.sessionVariables.GODOT_WAYLAND_DISABLE_EMBEDDER = "1";
    home.activation.disableGodotGameEmbedding = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings="${config.home.homeDirectory}/.config/godot/editor_settings-4.7.tres"
      mkdir -p "$(dirname "$settings")"
      touch "$settings"

      if grep -q '^run/window_placement/game_embed_mode' "$settings"; then
        sed -i 's|^run/window_placement/game_embed_mode = .*|run/window_placement/game_embed_mode = -1|' "$settings"
      else
        printf '\nrun/window_placement/game_embed_mode = -1\n' >> "$settings"
      fi
    '';

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        "image/*" = [ "qimgv.desktop" ];
        "image/gif" = [ "qimgv.desktop" ];
        "image/jpeg" = [ "qimgv.desktop" ];
        "image/png" = [ "qimgv.desktop" ];
        "image/webp" = [ "qimgv.desktop" ];
        "audio/*" = [ "mpv.desktop" ];
        "video/*" = [ "mpv.desktop" ];
      };
    };

    xdg.configFile = {
      "gtk-3.0/bookmarks".text = ''
        file:///mnt/data Data
        file:///mnt/archive Archive
        file:///mnt/media Media
        file:///mnt/downloads Downloads
        file:///mnt/portable_apps Portable Apps
        file:///mnt/workspace Workspace
        file:///mnt/ssh SSH
      '';
      "niri/config.kdl".source = ./conf/config.kdl;
      "niri/keybindings.kdl".source = ./conf/keybindings.kdl;
      "niri/niri-hardware.kdl".source = ./conf/niri-hardware.kdl;
      "niri/noctalia-shell.kdl".source = ./conf/noctalia-shell.kdl;
      "niri/spawn-at-startup.kdl".source = ./conf/spawn-at-startup.kdl;
      "niri/windowrules.kdl".source = ./conf/windowrules.kdl;
    };

    # Nautilus replaces Thunar's uca.xml. The "open in terminal" action comes
    # from nautilus-open-any-terminal (system side, configured for kitty), and
    # "open in VS Code" from this extension. Nautilus has no declarative action
    # format -- nautilus-actions is dead -- so a python MenuProvider is the
    # supported path.
    #
    # xdg.dataFile, not xdg.configFile: nautilus-python searches
    # ~/.local/share/nautilus-python/extensions (plus its DATADIR), never
    # ~/.config. It is loaded at all only because the system module sets
    # NAUTILUS_4_EXTENSION_DIR (see modules/nixos/desktop/niri.nix).
    xdg.dataFile."nautilus-python/extensions/nix-config-actions.py".text = ''
      # Managed by nix-config. Adds "在 VS Code 中打开" to the Nautilus
      # context menu, the counterpart of the old Thunar custom action.

      from gi.repository import Nautilus, GObject
      from subprocess import Popen

      VSCODE = "${pkgs.vscode}/bin/code"


      class NixConfigActions(GObject.GObject, Nautilus.MenuProvider):
          def _launch(self, menu, files):
              args = [VSCODE]
              # A directory selection means "open this folder as a project",
              # which is what the Thunar action did with `%f`.
              if any(f.is_directory() for f in files):
                  args.append("--new-window")
              args.extend(f.get_location().get_path() for f in files)
              Popen(args, start_new_session=True)

          def get_file_items(self, files):
              if not files:
                  return []
              # Only for local files; GVFS/tracker URIs have no plain path.
              if any(f.get_uri_scheme() != "file" for f in files):
                  return []
              item = Nautilus.MenuItem(
                  name="NixConfigActions::open_vscode",
                  label="在 VS Code 中打开",
                  tip="Open the selection in VS Code",
                  icon="vscode",
              )
              item.connect("activate", self._launch, files)
              return [item]

          def get_background_items(self, current_folder):
              item = Nautilus.MenuItem(
                  name="NixConfigActions::open_vscode_bg",
                  label="在 VS Code 中打开",
                  tip="Open this folder in VS Code",
                  icon="vscode",
              )
              item.connect("activate", self._launch, [current_folder])
              return [item]
    '';

    # nautilus-open-any-terminal ships zh_CN translations ("在此处打开{}"),
    # but its gettext lookup only probes two hardcoded directories:
    #
    #   ~/.local/share/locale
    #   /usr/share/locale
    #
    # On NixOS the catalogs live in the package's own store path
    # ($out/share/locale), so neither hits and the menu silently stays English
    # even with LANG=zh_CN.UTF-8. Dropping the catalog into the first probed
    # directory fixes it without patching the package.
    #
    # The path is deliberately the standard <locale>/LC_MESSAGES/<domain>.mo
    # layout, which is what gettext.translation() expects.
    xdg.dataFile."locale/zh_CN/LC_MESSAGES/nautilus-open-any-terminal.mo".source =
      "${pkgs.nautilus-open-any-terminal}/share/locale/zh_CN/LC_MESSAGES/nautilus-open-any-terminal.mo";

    systemd.user.services.niri-flake-polkit = {
      Unit = {
        Description = "PolicyKit Authentication Agent provided by niri-flake";
        After = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
      };
      Install.WantedBy = [ "niri.service" ];
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
