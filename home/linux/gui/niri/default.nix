{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.niri;

  python = pkgs.python3.withPackages (ps: [ ps.dbus-next ]);

  globalShortcutsBridge = pkgs.writeShellApplication {
    name = "niri-global-shortcuts";
    runtimeInputs = [ python ];
    text = ''
      exec python3 ${./niri-global-shortcuts.py}
    '';
  };

  globalShortcut = pkgs.writeShellApplication {
    name = "niri-global-shortcut";
    runtimeInputs = [ pkgs.glib ];
    text = ''
      exec gdbus call \
        --session \
        --dest org.gnome.Shell \
        --object-path /org/nixos/NiriGlobalShortcuts \
        --method org.nixos.NiriGlobalShortcuts.Activate \
        "$1"
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
      globalShortcut
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

    # xdg-desktop-portal-gnome implements GlobalShortcuts through the GNOME
    # Shell API, which niri does not provide. Bridge the registration calls so
    # applications such as WeChat can bind shortcuts and Niri can trigger them.
    systemd.user.services.niri-global-shortcuts = {
      Unit = {
        Description = "Global shortcut bridge for niri";
        Before = [ "graphical-session.target" ];
        After = [ "dbus.service" ];
      };
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "simple";
        ExecStart = lib.getExe globalShortcutsBridge;
        Restart = "on-failure";
        RestartSec = 1;
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
