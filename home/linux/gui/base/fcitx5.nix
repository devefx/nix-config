{ pkgs, ... }:
# Chinese input method via fcitx5. The `fcitx5-chinese-addons` bundle
# includes Pinyin, Shuangpin (双拼), Wubi (五笔), Zhuyin (注音) and
# more — pick your scheme in the config UI after first launch.
#
# First-launch setup:
#   1. Log out and back in (or reboot) so fcitx5 starts with the session.
#   2. Run `fcitx5-configtool` (or click the system tray icon).
#   3. Add "Pinyin" (or Shuangpin / whatever) to your enabled methods.
#   4. Keep "Keyboard - English (US)" as the first entry.
#   5. Switch with Ctrl+Space (default).
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";

    # Plasma 6 runs Wayland — use the native text-input-v3 protocol
    # instead of the legacy XMODIFIERS / *_IM_MODULE env vars.
    fcitx5.waylandFrontend = true;

    # waylandFrontend avoids exporting X11 env vars for native Wayland apps,
    # but Steam and other XWayland apps still need them for fcitx5.
    fcitx5.sessionVariables = {
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      GLFW_IM_MODULE = "fcitx";
      SDL_IM_MODULE = "fcitx";
    };

    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-configtool # GUI config tool
      fcitx5-gtk # GTK app integration
      qt6Packages.fcitx5-chinese-addons # Pinyin / Shuangpin / Wubi / Zhuyin — all in one

      # Catppuccin theme, matching the terminal (kitty, yazi) and the prompt
      # (starship). An addon rather than a hand-written theme.conf: the package
      # ships one directory per flavour x accent (56 in total), and fcitx5
      # finds them because with-addons.nix symlinkJoins every addon into the
      # fcitx5 package and appends its `share` to XDG_DATA_DIRS.
      #
      # `withRoundedCorners` turns on the port's panel.svg/highlight.svg
      # backgrounds instead of flat rectangles, matching the 20px window radius
      # niri applies to the rest of the desktop.
      #
      # `mauve` for the accent, the same choice as yazi's theme: it is the value
      # the Catppuccin kitty port uses for its active tab, so the three agree.
      (catppuccin-fcitx5.override { withRoundedCorners = true; })
    ];

    # `Theme` selects which of the shipped theme directories to use. Only the
    # name is set here; the colours live in the package above.
    fcitx5.settings.addons.classicui.globalSection = {
      Font = "Noto Sans 12";
      MenuFont = "Noto Sans 12";
      TrayFont = "Noto Sans 12";
      Theme = "catppuccin-macchiato-mauve";

      # The default is `True` for both, which would tint the panel with the
      # system colour scheme (KDE/GTK) and override the theme's own surface
      # colour. The port's #363A4F (surface0) only shows up with these off.
      UseCustomFont = "False";
      UseDarkTheme = "False";
      UseAccentColor = "False";
    };
  };
}
