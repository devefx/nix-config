{
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

    # Orchis (vinceliuice, Material Design) covers both GTK 3 and GTK 4, which
    # matters here because Nautilus 50 is GTK4/libadwaita while the rest of the
    # desktop (Firefox, VS Code, file pickers) is GTK3.
    #
    # Orchis-Dark, not Orchis: the plain `Orchis` variant is a hybrid --
    # theme_bg_color #F2F2F2 (light content) with a dark headerbar/wm_bg
    # #2C2C2C, which reads as broken once the rest of the desktop is dark. Only
    # -Dark is dark throughout (window_bg_color #212121, view_bg_color #2C2C2C,
    # fg white, accent #3281EA).
    #
    # No GTK2 from Orchis: upstream's gtk-2.0 themes need a Murrine engine that
    # nixpkgs no longer packages, so the nixpkgs derivation patches the GTK2
    # step out (pkgs/by-name/or/orchis-theme/remove-gtk2.patch). gtk2.theme is
    # nulled below to match.
    theme = {
      name = "Orchis-Dark";
      package = pkgs.orchis-theme;
    };

    # Papirus-Dark, matching the Qt side exactly: qt6ct.conf, the nwg-hello
    # greeter (modules/nixos/desktop/niri.nix) and the nixpak sandboxes
    # (hardening/nixpaks/modules/gui-base.nix) all use Papirus-Dark, so the bar,
    # the greeter, sandboxed apps and now every GTK app share one icon set.
    #
    # Papirus is its own project (PapirusDevelopmentTeam/papirus-icon-theme,
    # based on the Paper icon set), not an Orchis asset -- Orchis is a GTK theme
    # only and ships no icons, so this pairing is arbitrary-but-conventional
    # rather than upstream-matched.
    #
    # Inherits=breeze-dark,hicolor, so symbolic glyphs missing from Papirus-Dark
    # still resolve. Note the previously-used Colloid-Dark inherited
    # hicolor,breeze (light) instead; Papirus-Dark's fallback chain is the one
    # the Qt side already validated.
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    # Naming a dark theme is not enough on its own: without this, libadwaita
    # apps keep following the default (light) scheme regardless of
    # gtk-theme-name. Setting it writes gtk-application-prefer-dark-theme=true
    # for GTK 3, gtk-interface-color-scheme for GTK 4, and prefer-dark into the
    # dconf org/gnome/desktop/interface color-scheme.
    colorScheme = "dark";

    # null, not `config.gtk.theme`: setting it makes home-manager write a
    # ~/.config/gtk-4.0/gtk.css that @imports the whole Orchis GTK4 stylesheet
    # as *user* CSS, which outranks libadwaita's own stylesheet. Orchis is a
    # GTK3-era theme, so its Nautilus sidebar rules (a nine-slice
    # row-selected-dark.png border-image) then land on Nautilus 50's
    # libadwaita sidebar and draw the selection as a half-length slab.
    # Leaving it null keeps libadwaita apps (Nautilus, GNOME dialogs) on stock
    # Adwaita Dark while GTK 3 apps still get Orchis-Dark via gtk.theme above.
    gtk4.theme = null;

    font = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 11;
    };

    # Orchis has no gtk-2.0 directory (see the theme comment above), so naming
    # it here would point ~/.gtkrc-2.0 at a theme GTK2 cannot find and silently
    # fall back to Raleigh. There is no GTK2 app on this system that reads the
    # file anyway -- the gtk+-2.24.33 in the system closure is pulled in by the
    # Lutris FHS env, not by an app -- so keep the file (cursor/font/icon keys
    # are still correct) and just drop the theme name.
    gtk2.theme = null;

    # Force-rewrite ~/.gtkrc-2.0 without backup: home-manager fully owns
    # this generated file, and nixpkgs bumps change its content, which
    # otherwise collides with the stale `.home-manager.backup` copy.
    gtk2.force = true;
  };
}
