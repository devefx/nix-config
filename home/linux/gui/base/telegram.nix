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
# skip the Qt/tdlib closure; `modules.telegram.second.enable` adds a
# second instance for a second account. Chat data lives in the nixpak
# data dir — ~/.var/app/org.telegram.desktop/data/TelegramDesktop/ —
# so it survives rebuilds but stays isolated from the rest of $HOME.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.telegram;
in
{
  options.modules.telegram = {
    enable = mkEnableOption "sandboxed Telegram Desktop (nixpak)";
    second.enable = mkEnableOption "second sandboxed Telegram Desktop instance (nixpak, separate account and data dir)";
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      home.packages = [ pkgs.nixpaks.telegram-desktop ];
    })
    # Independent switch: the second instance works with or without the first. Why it needs
    # its own appId and workdir: hardening/nixpaks/telegram-desktop-2.nix.
    (mkIf cfg.second.enable {
      home.packages = [ pkgs.nixpaks.telegram-desktop-2 ];
    })
  ];
}
