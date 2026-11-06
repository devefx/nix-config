{
  config,
  lib,
  myvars ? { },
  ...
}:
# Syncthing, sharing this machine's game saves with a Syncthing server.
#
# Named after the program rather than the goal (`save-sync`) because nothing
# here is a generic sync layer: the options are Syncthing's own — override
# flags, ignore patterns, staggered versioning — and swapping in rclone would
# mean rewriting the module, not changing a setting.
#
# Syncthing rather than rclone or a plain rsync loop because the saves move
# between machines in both directions: the server is a copy to fall back on, and
# after a reinstall Syncthing hands the saves back on its own. A version history
# on both ends covers the case where a save is overwritten by a stale copy,
# which a plain `rsync --delete` would turn into data loss.
#
# Only the save directories are shared. The directories around them hold the
# game files, shader caches and settings, none of which belongs on another
# machine.
#
# The folders are declared here. They are shared with nobody until
# `server.id` is filled in, which is what makes the first-time pairing a web UI
# step: add the server there, accept this machine on the server, then paste the
# server's device id (Actions > Show ID) into `server.id` and rebuild. After
# that the pairing is declared and the UI can no longer change it.
let
  inherit (lib)
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optionals
    optionalAttrs
    types
    ;

  cfg = config.modules.desktop.syncthing;

  # An empty id means the pairing has not been written down yet. The override
  # flags and the device list both hinge on it.
  serverDeclared = cfg.server.id != "";

  userGroup = config.users.users.${cfg.user}.group;

  # A tmpfiles line for a directory Syncthing has to own. `d` is idempotent and
  # leaves an existing directory's owner alone.
  ownedDir = path: "d ${path} 0755 ${cfg.user} ${userGroup} -";
in
{
  options.modules.desktop.syncthing = {
    enable = mkEnableOption "Syncthing, set up to share the game saves";

    user = mkOption {
      type = types.str;
      default = myvars.username or "nobody";
      description = ''
        The user Syncthing runs as. It has to own the save folders, which the
        game modules already arrange.
      '';
    };

    server = {
      id = mkOption {
        type = types.str;
        default = "";
        example = "AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFFF-GGGGGGG-HHHHHHH";
        description = ''
          The Syncthing device id of the server (on the server: Actions > Show
          ID).

          Empty means "pair through the web UI": no device is declared, the
          folder list stays editable, and the folders start out shared with
          nobody. Add the server in the UI, accept this machine on the server,
          then put the id here and rebuild. From then on the pairing is
          declared and the UI can no longer change it.
        '';
      };

      addresses = mkOption {
        type = types.listOf types.str;
        default = [ "dynamic" ];
        example = [ "tcp://nas.local:22000" ];
        description = ''
          Where to reach it. `dynamic` uses discovery; a fixed address skips
          the lookup and works without a discovery server on the LAN.
        '';
      };
    };

    # No default: which directories leave this machine is the decision the
    # module exists for, so the host has to spell it out.
    folders = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              example = "/var/lib/savagewind/save";
              description = "Where the folder lives on this machine.";
            };

            label = mkOption {
              type = types.str;
              default = "";
              description = ''
                What the web UI calls it. Local only — the server may show a
                different label for the same folder.
              '';
            };

            group = mkOption {
              type = types.str;
              default = "";
              example = "Zelda";
              description = ''
                Which group the web UI files it under. Local only, and purely
                cosmetic: Syncthing 2.1 added `group` so the folder list can be
                collapsed, and it takes no part in sharing. Empty leaves the
                folder ungrouped.

                Syncthing before 2.1 rejects the attribute, so leave it empty
                when the service is older than that.
              '';
            };
          };
        }
      );
      example = {
        "savage-wind-save" = {
          path = "/var/lib/savagewind/save";
          label = "Zelda: Breath of the Wild saves";
          group = "Zelda";
        };
      };
      description = ''
        Folder id to local directory.

        The id is the only thing the two machines agree on: it is what a
        Syncthing folder *is*. The path is local and never leaves this machine,
        which is why the server can put the same id at a completely different
        directory. Renaming an id therefore does not move anything — it asks
        the server for a new folder and starts the transfer from scratch.

        The server side is mapped once, when it accepts the share: the web UI
        asks which directory to use and remembers the answer in its own
        `config.xml`. Nothing here can set it, because the server is not part of
        this configuration.
      '';
    };

    versionsPath = mkOption {
      type = types.str;
      default = "/var/lib/syncthing-versions";
      description = ''
        Where the version history goes. Kept out of the save folders: a
        `.stversions` inside them would be scanned and synced as game files.
      '';
    };

    rescanIntervalS = mkOption {
      type = types.int;
      default = 3600;
      description = ''
        How often to walk the folders in full, in seconds.

        This is the fallback, not the mechanism: `fsWatcherEnabled` catches
        changes as they happen, and a periodic walk only repairs whatever the
        watcher missed. The saves are on local ext4, where inotify is reliable,
        so the default hour is enough. Lower it to a few minutes only if a
        folder ever moves to a filesystem without working watches — a Docker
        volume, NTFS, or an SMB mount.
      '';
    };

    fsWatcherDelayS = mkOption {
      type = types.int;
      default = 30;
      description = ''
        Seconds to wait after the last change before syncing.

        A save is not written atomically: the game truncates and rewrites it,
        and an autosave can restart that mid-way. The default of 10 is tuned for
        documents edited by hand; 30 costs nothing here and makes it far less
        likely that a half-written save is the version that travels. The timer
        restarts on every change, so a game that keeps writing simply keeps
        waiting.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      inherit (cfg) user;
      dataDir = "/home/${cfg.user}";
      configDir = "/home/${cfg.user}/.config/syncthing";
      # 22000/tcp and 21027/udp for syncing; the web UI stays on 127.0.0.1.
      openDefaultPorts = true;
      # Only take control once the server is declared, so that a pairing done
      # in the UI survives a rebuild.
      overrideDevices = serverDeclared;
      overrideFolders = serverDeclared;

      settings = {
        devices = optionalAttrs serverDeclared {
          server = {
            inherit (cfg.server) id addresses;
          };
        };

        folders = mapAttrs (name: folder: {
          inherit (folder) path;
          inherit (cfg) rescanIntervalS fsWatcherDelayS;
          fsWatcherEnabled = true;
          label = if folder.label != "" then folder.label else name;
          group = folder.group;
          # Empty until `server.id` is set: the folder exists but is shared
          # with nobody, so picking the server is a UI step.
          devices = optionals serverDeclared [ "server" ];
          # `save.lock` exists while the game runs and is pure runtime state.
          # The conflict pattern is defensive: one machine plays at a time, so
          # a conflict should never appear, and if one ever does it must not be
          # synced onward as a game file.
          ignorePatterns = [
            "save.lock"
            "*.tmp"
            "*.partial"
            "*.sync-conflict-*"
          ];
          versioning = {
            type = "staggered";
            params = {
              maxAge = "30";
              cleanInterval = "3600";
              maxVersions = "10";
              versionsPath = "${cfg.versionsPath}/${name}";
            };
          };
        }) cfg.folders;
      };
    };

    # Syncthing creates these itself, but the parent has to exist and belong to
    # the user before the first start: on a fresh machine Syncthing may come up
    # before the game provisioner has run, and it cannot create /var/lib/totk as
    # an unprivileged user.
    systemd.tmpfiles.rules = [
      (ownedDir cfg.versionsPath)
    ]
    ++ lib.concatLists (
      mapAttrsToList (name: folder: [
        (ownedDir (builtins.dirOf folder.path))
        (ownedDir folder.path)
        (ownedDir "${cfg.versionsPath}/${name}")
      ]) cfg.folders
    );
  };
}
