{
  lib,
  godotYoke,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.godot;
in
{
  options.modules.godot = {
    enable = mkEnableOption "custom Godot 4.7 build from MHGameDevs/godot yoke branch";
  };

  config = mkIf cfg.enable {
    home.packages = [
      godotYoke
    ];
  };
}
