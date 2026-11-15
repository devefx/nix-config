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

    # The colours come from Noctalia, not from this file: its `kitty` template
    # writes `~/.config/kitty/themes/noctalia.conf` on every palette change, and
    # the `globinclude` in `extraConfig` below loads it. home-manager renders
    # `extraConfig` last (themeFile at order 520, settings 540, keybindings 560,
    # user extraConfig 1000), so the Noctalia file wins over everything above it.
    #
    # `globinclude` rather than `include`: kitty reports a missing `include`
    # target as a config error, while a glob that matches nothing is silent --
    # which matters on a fresh install before Noctalia has ever run.
    #
    # `themeFile` stays as the fallback for exactly that case: the Catppuccin
    # Macchiato port from `pkgs.kitty-themes`, the same palette
    # `home/base/core/starship.nix` and the yazi/bat themes still use, so a
    # session without Noctalia keeps the terminal and the prompt consistent
    # instead of dropping to kitty's built-in black.
    #
    # Consequence to keep in mind: the shell palette is Nord (see `[theme]` in
    # home/linux/gui/niri/noctalia/config.toml) while the prompt is still
    # Catppuccin, so the prompt's `base`-coloured blocks sit on Nord's #2e3440
    # background. Moving starship/yazi/bat to Nord is what would make the whole
    # terminal one palette again.
    themeFile = "Catppuccin-Macchiato";

    # Last in the rendered file, so it overrides `themeFile` and `settings`.
    # The pattern matches only the file Noctalia writes; if it is absent the
    # glob silently matches nothing and the fallback theme above applies.
    extraConfig = ''
      # Palette pushed by Noctalia's kitty template; see themeFile above.
      globinclude themes/noctalia*.conf
    '';

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
      # window-rule in noctalia.kdl sets geometry-corner-radius.
      hide_window_decorations = "titlebar-only";

      # Fully opaque, so the background is the theme's #24273A and nothing else.
      #
      # This used to be "0.93". At 93% the terminal blended the theme background
      # with whatever sat behind the window, so the colour that reached the eye
      # was not #24273A but #24273A mixed with the wallpaper -- measured #212436
      # over black, #2A2D3F over a bright wallpaper patch. That is why the
      # terminal did not match the Catppuccin-Macchiato screenshots, which are
      # rendered opaque. Transparency is incompatible with "show the theme's
      # colour exactly"; pick one.
      background_opacity = "1.0";

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
