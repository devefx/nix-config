# Miscellaneous GUI apps (messaging, e-book, etc.)
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # sandboxed messaging apps
    nixpaks.qq
    nixpaks.telegram-desktop
    bwraps.wechat # bubblewrap sandboxed AppImage
  ];

  # Install fonts at system-level, not user-level
  fonts.fontconfig.enable = false;
}
