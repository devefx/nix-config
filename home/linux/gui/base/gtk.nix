{
  config,
  pkgs,
  ...
}:
# GTK theme / icons / cursor / fonts — applies to every GTK app regardless of
# the desktop: Nautilus, Firefox, VS Code, file pickers, ... (Plasma itself uses
# its own Qt theme; Qt apps only pick GTK up through the platform theme plugin).
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  gtk = {
    enable = true;

    # Colloid covers both GTK 3 and GTK 4, which matters here because Nautilus
    # 50 is GTK4/libadwaita while the rest of the desktop (Firefox, VS Code,
    # file pickers) is GTK3. The package also ships GTK2.
    #
    # Colloid-Light, not Colloid: the plain `Colloid` variant is a hybrid --
    # white content area but a dark titlebar/border (wm_bg #242424). Only the
    # -Light variant is light throughout (wm_bg #F2F2F2).
    theme = {
      name = "Colloid-Light";
      package = pkgs.colloid-gtk-theme;
    };

    # Same palette as the GTK theme, so the folder glyphs in the file manager
    # match the window chrome instead of clashing with Papirus.
    iconTheme = {
      name = "Colloid-Light";
      package = pkgs.colloid-icon-theme;
    };

    # Naming a light theme is not enough on its own: without this, GTK still
    # asks for the dark variant of whatever is active and libadwaita apps stay
    # dark. Setting it writes gtk-application-prefer-dark-theme=false for
    # GTK 3, gtk-interface-color-scheme=3 for GTK 4, and prefer-light into the
    # dconf org/gnome/desktop/interface color-scheme.
    colorScheme = "light";

    # Nautilus 50 is GTK4/libadwaita, so the GTK4 side matters here as much as
    # GTK3. home-manager's default for gtk4.theme changed from "inherit
    # gtk.theme" to null; stateVersion here is 25.11 so the legacy inheritance
    # still applies, but it warns on every evaluation. Pin it explicitly to
    # keep the same behaviour without the noise.
    gtk4.theme = config.gtk.theme;

    font = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 11;
    };

    # Force-rewrite ~/.gtkrc-2.0 without backup: home-manager fully owns
    # this generated file, and nixpkgs bumps change its content, which
    # otherwise collides with the stale `.home-manager.backup` copy.
    gtk2.force = true;
  };
}
