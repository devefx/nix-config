{
  config,
  lib,
  pkgs,
  ...
}:
# Qt theming for the niri session: the Qt half of the Orchis-Dark look that
# home/linux/gui/base/gtk.nix applies to GTK apps.
#
# The mechanism, in one place because it spans four files:
#
#   1. pkgs/orchis-kde            ships share/Kvantum/Orchis{,-solid}, the Qt port
#                                 of the same Orchis design (vinceliuice).
#   2. this file                  installs it plus qt6ct and
#                                 qtstyleplugin-kvantum, and writes the two
#                                 config files under niri/qt/.
#   3. niri/conf/config.kdl       exports QT_QPA_PLATFORMTHEME=qt6ct to every
#                                 process niri spawns.
#   4. qt6ct.conf + kvantum.kvconfig
#                                 select style=kvantum and theme=OrchisDark.
#
# Steps 1-2 are gated on the niri option: Plasma has its own Qt theming through
# programs.plasma (home/linux/gui/plasma.nix), and qt6ct would fight it.
lib.mkIf config.modules.desktop.niri.enable {
  home.packages = [
    (pkgs.callPackage ../../../../pkgs/orchis-kde { })
    pkgs.qt6Packages.qt6ct
    pkgs.qt6Packages.qtstyleplugin-kvantum
    # Window decorations for native-Wayland Qt apps. Kvantum themes the widgets
    # *inside* a window; the title bar is drawn by Qt's wayland-decoration-client
    # plugin instead, and without one Qt draws its own light-grey bar (measured
    # #95989a against the #212121 window, which is the mismatch that reads as
    # "the border did not change").
    #
    # qtwayland's own `libadwaita.so` (Qt 6.9 upstreamed QAdwaitaDecorations).
    #
    # Known upstream limitation: the buttons never repaint on hover.
    # QWaylandAbstractDecoration::update() only sets a dirty flag and wayland
    # windows have no QBackingStore, so nothing schedules a redraw; clicks still
    # work. Fixing it needs a requestUpdate() inside the plugin, i.e. patching
    # qtbase or a patched qadwaitadecorations-qt6 -- not worth the rebuild.
    #
    # Requires QT_WAYLAND_DECORATION=adwaita (set in niri/conf/config.kdl) *and*
    # a native-Wayland Qt app: the plugin is a QWaylandDecorationFactory, so it
    # is never loaded under XWayland. Measured: eden on xcb loads libqxcb.so and
    # no decoration plugin at all; with QT_QPA_PLATFORM=wayland it loads
    # libqwayland.so + libadwaita.so and the bar goes from rgb(149,152,154) to
    # rgb(44,45,47).
    pkgs.qt6Packages.qtwayland
    # Icon source for those three title-bar buttons, and nothing else.
    # The decoration plugin looks the glyphs up by name (`window-close-symbolic`
    # etc.) by walking QIcon::themeSearchPaths() with QDirIterator, which does
    # *not* follow directory symlinks -- and Papirus-Dark's `symbolic/` is
    # exactly that (`16x16/symbolic -> ../../Papirus/16x16/symbolic`), while the
    # non-symbolic `window-close.svg` in `actions/` does not match the name it
    # searches for. Measured: with Papirus-Dark as the Qt icon theme all three
    # buttons render as empty grey circles. The plugin's last-resort fallback
    # theme name is hardcoded to "Adwaita", which ships real directories, so this
    # package alone fixes the buttons; the SVGs are re-tinted with the title
    # bar's foreground colour, so Adwaita's fixed #2e3436 fill is irrelevant.
    pkgs.adwaita-icon-theme
  ];

  xdg.configFile = {
    # Kvantum's theme selection. The themes themselves come from the package
    # above via XDG_DATA_DIRS, not from a copy under ~/.config/Kvantum.
    "Kvantum/kvantum.kvconfig".source = ./qt/kvantum.kvconfig;
    "qt6ct/qt6ct.conf".source = ./qt/qt6ct.conf;
  };

  # niri's `environment` block (conf/config.kdl) only reaches processes niri
  # spawns. Anything started by a systemd user unit inherits
  # ~/.config/environment.d/10-home-manager.conf instead, so the same plugin
  # name has to be exported there too -- otherwise a Qt app launched from a
  # systemd service falls back to QGenericUnixTheme (light Fusion, hicolor-only
  # icons) while everything spawned by niri looks correct.
  systemd.user.sessionVariables.QT_QPA_PLATFORMTHEME = "qt6ct";
}
