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

    # Catppuccin Macchiato, matching the starship prompt's palette
    # (`home/base/core/starship.nix` uses `catppuccin_macchiato`). One palette
    # across the terminal and the prompt means the prompt's `base`-coloured
    # ends and the terminal background are the same family of dark blue-grey
    # instead of two slightly different rectangles.
    #
    # `themeFile` rather than an `include` line in `settings`: home-manager
    # renders `themeFile` at order 520 and `settings` at 540, so the theme is
    # included first and anything in `settings` can still override it. Putting
    # the include inside `settings` would not give that guarantee -- attrsets
    # render in alphabetical order, so `background_opacity` would land before
    # `include` and the theme would win.
    #
    # kitty's own package ships no theme files; `themeFile` pulls them from
    # `pkgs.kitty-themes`, the same collection `kitten themes` lists. Its
    # Catppuccin entries are the upstream ports from catppuccin/kitty, so the
    # colour values are the canonical ones, not a re-derivation.
    #
    # Three of the port's settings are load-bearing here: `background`
    # #24273A (Macchiato `base`, the colour the prompt's first and last blocks
    # sit on), `foreground` #CAD3F5 (`text`), and `color1` #ED8796 -- the ANSI
    # red is the same value as the prompt's `red` segment, so shell errors and
    # the `$os`/`$username` block match. Its `cursor` is #F4DBD6 (rosewater)
    # rather than white, deliberately tinted to read as part of the palette.
    #
    # The port also sets tab and border colours. They only show up once a second
    # tab exists (`tab_bar_min_tabs` defaults to 2) or a window is split into
    # several panes, but they are part of the same palette, so leaving them is
    # what makes the tab bar match instead of falling back to kitty's defaults.
    themeFile = "Catppuccin-Macchiato";

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

    # Keep terminal output, CLI errors, and man pages in English even though
    # the surrounding Niri desktop session uses Chinese GUI messages.
    environment = {
      LANGUAGE = "en_US";
      LC_MESSAGES = "en_US.UTF-8";
    };

    settings = {
      # Hide kitty's own title bar. `titlebar-and-corners` (the previous value)
      # is documented as macOS-only; on Wayland only `titlebar-only` hides the
      # title bar, while still forcing client-side decoration mode so the resize
      # shadow survives. Under `titlebar-and-corners` this session drew a title
      # bar with CSD buttons, which clashed with niri's decoration-less look.
      #
      # The 20px corner radius comes from niri, not kitty: the catch-all
      # window-rule in noctalia-shell.kdl sets geometry-corner-radius.
      hide_window_decorations = "titlebar-only";

      # Slight transparency — set to "1.0" for fully opaque.
      background_opacity = "0.93";

      # No annoying beep on errors.
      enable_audio_bell = false;

      # Tab bar on top (matches most modern terminal UIs).
      tab_bar_edge = "top";

      # macOS only: none of these do anything on Linux.
      macos_show_window_title_in = "none";
      macos_option_as_alt = true; # treat Option as Alt so Emacs/Vim meta-keys work
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
  xdg.dataFile."applications/kitty.desktop".source = "${pkgs.kitty}/share/applications/kitty.desktop";
}
