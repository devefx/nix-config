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
      # nixpkgs builds moonlight-qt 6.1.0 against ffmpeg_8, which it still
      # requires after ffmpeg 9 removed AVVulkanDeviceContext decode fields.
      pkgs.moonlight-qt
    ];
  };
}
