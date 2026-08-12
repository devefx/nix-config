{
  lib,
  pkgs,
  config,
  ...
}:
# ComfyUI — node-based Stable Diffusion / diffusion model workflow UI.
#
# Uses a custom ROCm build for the AMD Radeon 8060S (gfx1151 / Strix Halo)
# instead of nixpkgs' CPU-only PyTorch. The upstream writable-runtime-paths
# patch keeps models, custom nodes, input, output, and user data under
# `~/.local/share/comfyui`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.comfyui;

  comfyui-rocm = pkgs.callPackage ../../../../pkgs/comfyui-rocm { };
in
{
  options.modules.comfyui = {
    enable = mkEnableOption "ComfyUI";
  };

  config = mkIf cfg.enable {
    home.packages = [ comfyui-rocm ];
  };
}
