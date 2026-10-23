{
  lib,
  pkgs,
  config,
  ...
}:
# mpv — akFace/mpv.config (zh-CN) as the default video player.
#
# https://github.com/akFace/mpv.config
#
# The config tree is *copied* into ~/.config/mpv at activation time instead of
# being symlinked from the store. Several bundled scripts write next to their
# own configuration: switch-opts rewrites script-opts/*.conf when you pick a
# theme from the right-click menu, skip-intro stores per-file marks,
# recentmenu stores history, equalizer-gui stores an EQ. A read-only store
# symlink would break all of them, so `programs.mpv`'s own config writers are
# deliberately left unused -- it only provides the wrapped player binary.
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.modules.mpv;

  akfaceConfig = pkgs.callPackage ../../../../pkgs/mpv-akface-config { } // {
    inherit (cfg) skin;
  };

  configTree = akfaceConfig.mkConfig cfg.skin;
in
{
  options.modules.mpv = {
    enable = mkEnableOption "mpv with an akFace/mpv.config skin";

    skin = mkOption {
      type = types.enum [
        "modernz"
        "modern_glass"
        "uosc"
      ];
      default = "modern_glass";
      description = ''
        Which akFace/mpv.config skin to install. Skins ship different script
        sets (e.g. `modernz` uses thumbfast, `modern_glass` uses thumbz), so
        switching also prunes files belonging to the previous skin.
      '';
    };
  };

  config = mkIf cfg.enable {
    programs.mpv = {
      enable = true;
      # MPRIS / media keys for the Noctalia media widget and playerctl. This
      # only rewrites the mpv wrapper, it does not touch the config tree.
      #
      # No `config`, `bindings` or `scriptOpts` here on purpose: home-manager
      # would write mpv.conf/input.conf/script-opts/*.conf and clash with the
      # upstream tree copied in below.
      scripts = [ pkgs.mpvScripts.mpris ];
    };

    home.packages = [
      # modernz' "download" button and yt-dlp-backed stream handling shell out
      # to yt-dlp; ffmpeg is already installed by other modules.
      pkgs.yt-dlp
    ];

    home.activation.mpvAkfaceConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      configDir="${config.home.homeDirectory}/.config/mpv"
      stamp="$configDir/.akface-config"
      newStamp=${configTree}

      if [[ -f "$stamp" ]] && [[ "$(cat "$stamp")" == "$newStamp" ]]; then
        :
      else
        run mkdir -p "$configDir"

        # A previous generation managed these files as read-only store
        # symlinks; copying over them would write through to /nix/store. Drop
        # the stale links first so real files can take their place. Only links
        # into the store are touched, anything else in the directory survives.
        if [[ -d "$configDir" ]]; then
          find "$configDir" -type l -lname '/nix/store/*' -delete
        fi

        # Remove files shipped by the previously selected skin but absent from
        # this one. Without this, switching modernz -> modern_glass would leave
        # thumbfast.lua behind next to thumbz.lua, and both claim overlay id 42.
        # Runtime state (recent.json, danmaku history, skip-intro marks) is not
        # in any manifest and therefore preserved.
        if [[ -f "$stamp.manifest" ]]; then
          while IFS= read -r stale; do
            [[ -z "$stale" ]] && continue
            run rm -f "$configDir/$stale"
          done < <(LC_ALL=C comm -23 "$stamp.manifest" "$newStamp/.manifest")
        fi

        # -f so files copied by an earlier run can be replaced. Directories
        # merge, so runtime state is preserved across config bumps.
        run cp -rf "$newStamp"/. "$configDir"/

        # cp preserves the store's read-only modes, but the bundled scripts
        # write into this tree: switch-opts rewrites script-opts/*.conf when a
        # theme is picked, skip-intro and recentmenu drop JSON next to it.
        run chmod -R u+w "$configDir"

        run cp -f "$newStamp/.manifest" "$stamp.manifest"
        run sh -c "printf '%s\n' $newStamp > '$stamp'"
      fi
    '';
  };
}
