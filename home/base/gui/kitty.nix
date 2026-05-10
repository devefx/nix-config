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
}
