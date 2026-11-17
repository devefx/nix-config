{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed Telegram Desktop — nixpak-wrapped telegram-desktop. Package
# definition lives in hardening/nixpaks/telegram-desktop.nix and is
# exposed as pkgs.nixpaks.telegram-desktop.
#
# Gated behind `modules.telegram.enable` so hosts that don't need it
# skip the Qt/tdlib closure. Chat data lives in the nixpak data dir —
# ~/.var/app/org.telegram.desktop/data/TelegramDesktop/ — so it
# survives rebuilds but stays isolated from the rest of $HOME.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.telegram;
in
{
  options.modules.telegram = {
    enable = mkEnableOption "sandboxed Telegram Desktop (nixpak)";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.nixpaks.telegram-desktop ];
  };
}
