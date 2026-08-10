{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
# llama.cpp built with the Vulkan backend. On faex1 this uses RADV via
# the AMD Radeon 8060S iGPU; the `render` group is added at the system
# level so the user can access /dev/dri/renderD128.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.llamaCpp;
in
{
  options.modules.llamaCpp = {
    enable = mkEnableOption "llama.cpp with Vulkan backend";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.llama-cpp-vulkan
    ];

    programs.bash.profileExtra = lib.mkIf (osConfig.modules.secrets.hf.enable or false) ''
      export HF_TOKEN="$(cat ${osConfig.age.secrets.hf-token.path} 2>/dev/null)"
    '';
  };
}
