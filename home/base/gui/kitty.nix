{ pkgs, ... }:
# Kitty — fast, GPU-accelerated terminal emulator. Cross-platform
# (Linux + macOS) via home-manager's `programs.kitty`.
#
# Shortcuts (Linux uses ctrl+shift; macOS uses cmd):
#   ctrl+shift+=    increase font size
#   ctrl+shift+-    decrease font size
#   ctrl+shift+m    toggle maximized (custom binding below)
#   ctrl+shift+f    search scrollback (custom binding below)
{
  programs.kitty = {
    enable = true;

    # JetBrains Mono Nerd Font — already pulled in at system level by
    # modules/nixos/desktop/plasma.nix, but declare the package here too
    # so kitty works on hosts without that system module (future macOS).
    font = {
      name = "JetBrainsMono Nerd Font";
      package = pkgs.nerd-fonts.jetbrains-mono;
      size = 13;
    };

    keybindings = {
      "ctrl+shift+m" = "toggle_maximized";
      "ctrl+shift+f" = "show_scrollback";
    };

    settings = {
      # Clean look — hide title bar, keep rounded window corners.
      hide_window_decorations = "titlebar-and-corners";
      macos_show_window_title_in = "none";

      # Slight transparency — set to "1.0" for fully opaque.
      background_opacity = "0.93";

      # No annoying beep on errors.
      enable_audio_bell = false;

      # Tab bar on top (matches most modern terminal UIs).
      tab_bar_edge = "top";

      # On macOS: treat Option as Alt so Emacs/Vim meta-keys work.
      macos_option_as_alt = true;
    };

    # macOS: start maximized.
    darwinLaunchOptions = [ "--start-as=maximized" ];
  };

  # Keep the shipped logo under the app id in the user hicolor tree so KDE
  # icon lookups resolve `Icon=kitty` even when profile XDG paths differ.
  xdg.dataFile."icons/hicolor/128x128/apps/kitty.png".source =
    "${pkgs.kitty}/lib/kitty/logo/kitty-128.png";

  # Dolphin reads TerminalService with KDesktopFile, which only searches
  # ~/.local/share/applications for a relative desktop filename. Keep a
  # user-level copy there so its "Open Terminal Here" icon lookup can find
  # `Icon=kitty` instead of falling back to the generic terminal icon.
  xdg.dataFile."applications/kitty.desktop".source =
    "${pkgs.kitty}/share/applications/kitty.desktop";
}
