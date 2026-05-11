{
  lib,
  config,
  pkgs,
  ...
}:
# System fonts — baseline CJK + emoji + Nerd Fonts bundle.
#
# File lives in `modules/base/` because `fonts.packages` is one of the
# NixOS options that nix-darwin also implements, so this module is
# portable across both. The option is namespaced under `modules.desktop.*`
# because fonts conceptually belong to the desktop feature group (shared
# by Plasma / Hyprland / GNOME / ... once added).
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.desktop.fonts;
in
{
  options.modules.desktop.fonts = {
    enable = mkEnableOption "system font bundle (CJK + emoji + Nerd Fonts)";
  };

  config = mkIf cfg.enable {
    fonts.packages = with pkgs; [
      # Western
      dejavu_fonts
      liberation_ttf
      source-code-pro

      # CJK (Noto Sans/Serif CJK = thin wrappers over Source Han)
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif

      # Emoji
      noto-fonts-color-emoji

      # Dev/terminal — Nerd Fonts patched JetBrainsMono (icons + ligatures)
      nerd-fonts.jetbrains-mono
    ];
  };
}
