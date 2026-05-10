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

    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-configtool # GUI config tool
      fcitx5-gtk # GTK app integration
      fcitx5-chinese-addons # Pinyin / Shuangpin / Wubi / Zhuyin — all in one
    ];
  };
}
