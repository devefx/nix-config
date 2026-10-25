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

    # home-manager writes `gtk-interface-color-scheme` as the bare integer 2/3
    # (see mkGtkSettings in home-manager's modules/misc/gtk/lib.nix). That was
    # correct for older GTK 4, but GTK 4.22 made the property a proper enum,
    # GtkInterfaceColorScheme, whose values only parse from their nick strings:
    #
    #   value 0 = GTK_INTERFACE_COLOR_SCHEME_UNSUPPORTED (nick "unsupported")
    #   value 1 = GTK_INTERFACE_COLOR_SCHEME_DEFAULT     (nick "default")
    #   value 2 = GTK_INTERFACE_COLOR_SCHEME_DARK        (nick "dark")
    #   value 3 = GTK_INTERFACE_COLOR_SCHEME_LIGHT       (nick "light")
    #
    # So every GTK 4 app printed, on startup:
    #
    #   Gtk-WARNING **: Error setting gtk-interface-color-scheme in
    #   ~/.config/gtk-4.0/settings.ini: Key file contains key
    #   "gtk-interface-color-scheme" which has a value that cannot be
    #   interpreted.
    #
    # and then silently fell back to the default scheme -- the dark theme was
    # only taking effect through the other keys. Verified against GTK 4.22.4
    # with a minimal gtk_init() program: "light"/"dark"/"default"/
    # "unsupported" parse cleanly, 2 and 3 both warn.
    #
    # home-manager master already fixed this (it now writes the string
    # directly), but the flake is pinned to a home-manager from 2026-08-14.
    # Overriding the generated file's extraConfig keeps the fix local instead
    # of forcing a home-manager bump; drop this block once home-manager is
    # updated past that commit.
    gtk4.extraConfig = {
      "gtk-interface-color-scheme" = config.gtk.colorScheme;
    };

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
