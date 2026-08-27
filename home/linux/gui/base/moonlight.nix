{
  lib,
  pkgs,
  config,
  ...
}:
# Moonlight — open-source NVIDIA GameStream / Sunshine streaming client.
#
# Gated behind `modules.moonlight.enable` — enable in
# `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.moonlight;
in
{
  options.modules.moonlight = {
    enable = mkEnableOption "Moonlight game streaming client";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # ffmpeg 9 removed AVVulkanDeviceContext decode-queue fields that
      # moonlight-qt 6.1.0 still uses, so build against ffmpeg 8.
      (pkgs.moonlight-qt.override { ffmpeg = pkgs.ffmpeg_8; })
    ];
  };
}
