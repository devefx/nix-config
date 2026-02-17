# Instant messaging apps (sandboxed)
{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    nixpaks.qq
    nixpaks.telegram-desktop
    bwraps.wechat # bubblewrap sandboxed AppImage
  ];
}
