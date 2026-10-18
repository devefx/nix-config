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
      thunderbird
      qimgv # image viewer; imv-wayland can busy-loop after closing windows
      file-roller # backend for thunar-archive-plugin
      screenshotOcr
    ];

    programs.mpv = {
      enable = true;
      defaultProfiles = [ "gpu-hq" ];
      scripts = [ pkgs.mpvScripts.mpris ];
      config = {
        auto-window-resize = false;
        keepaspect = true;
        keepaspect-window = false;
        osc = true;
        osd-bar = true;
        panscan = 0.0;
        wayland-configure-bounds = "yes";
      };
      scriptOpts.osc = {
        boxvideo = true;
        visibility = "always";
      };
    };

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
        "inode/directory" = [ "thunar.desktop" ];
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
      '';
      "Thunar/uca.xml" = {
        force = true;
        text = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <actions>
            <action>
              <icon>vscode</icon>
              <name>在 VS Code 中打开</name>
              <unique-id>nix-config-open-vscode</unique-id>
              <command>${pkgs.vscode}/bin/code %f</command>
              <description>Open the selected folder in VS Code</description>
              <range></range>
              <patterns>*</patterns>
              <startup-notify/>
              <directories/>
            </action>
            <action>
              <icon>utilities-terminal</icon>
              <name>在终端中打开</name>
              <unique-id>nix-config-open-terminal</unique-id>
              <command>${pkgs.kitty}/bin/kitty --class nix-config-file-manager --working-directory %f</command>
              <description>Open a terminal in the selected folder</description>
              <range></range>
              <patterns>*</patterns>
              <startup-notify/>
              <directories/>
            </action>
          </actions>
        '';
      };
      "niri/config.kdl".source = ./conf/config.kdl;
      "niri/keybindings.kdl".source = ./conf/keybindings.kdl;
      "niri/niri-hardware.kdl".source = ./conf/niri-hardware.kdl;
      "niri/noctalia-shell.kdl".source = ./conf/noctalia-shell.kdl;
      "niri/spawn-at-startup.kdl".source = ./conf/spawn-at-startup.kdl;
      "niri/windowrules.kdl".source = ./conf/windowrules.kdl;
    };

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

    # greetd invokes this stable entry point instead of hard-coding a
    # compositor. It also handles restarting a stale niri user service.
    home.file.".wayland-session" = {
      source = pkgs.writeScript "init-session" ''
        systemctl --user is-active niri.service && systemctl --user stop niri.service
        exec ${pkgs.niri}/bin/niri-session
      '';
      executable = true;
    };
  };
}
