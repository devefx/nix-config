{
  lib,
  pkgs,
  config,
  ...
}:
# XDG thumbnailer for `.was` files. The provider decodes the WAS image
# container and writes standard thumbnails under `~/.cache/thumbnails`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.wasThumbnail;

  wasThumbnailProvider = pkgs.callPackage ../../../../pkgs/was-thumbnail-provider { };
in
{
  options.modules.wasThumbnail = {
    enable = mkEnableOption "WAS thumbnail provider";
  };

  config = mkIf cfg.enable {
    home.packages = [ wasThumbnailProvider ];

    xdg.dataFile."thumbnailers/was-thumbnail-provider.thumbnailer".source =
      "${wasThumbnailProvider}/share/thumbnailers/was-thumbnail-provider.thumbnailer";

    xdg.dataFile."mime/packages/was-thumbnail-provider.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
        <mime-type type="application/x-was">
          <comment>WAS image</comment>
          <glob pattern="*.was"/>
          <magic priority="60">
            <match value="SP" type="string" offset="0"/>
          </magic>
        </mime-type>
      </mime-info>
    '';

    home.activation.refreshWasMimeDb = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.shared-mime-info}/bin/update-mime-database "${config.home.homeDirectory}/.local/share/mime"
    '';
  };
}
