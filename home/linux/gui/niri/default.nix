{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.niri;
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
      imv
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
        "inode/directory" = [ "yazi.desktop" ];
        "image/*" = [ "imv-dir.desktop" ];
        "image/gif" = [ "imv-dir.desktop" ];
        "image/jpeg" = [ "imv-dir.desktop" ];
        "image/png" = [ "imv-dir.desktop" ];
        "image/webp" = [ "imv-dir.desktop" ];
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
