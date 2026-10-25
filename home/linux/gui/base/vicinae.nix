{
  lib,
  config,
  ...
}:
# Vicinae — native command palette / launcher (https://vicinae.com).
#
# Vicinae splits into a long-lived server and a thin client: `vicinae server`
# owns the window and the index, while `vicinae toggle` (what the Alt+Space
# bind in keybindings.kdl runs) is only an IPC call into that server. So the
# systemd unit is what actually matters here; without it the hotkey would spawn
# a second, competing server instead of raising the existing window.
#
# Gated behind `modules.vicinae.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.vicinae;
in
{
  options.modules.vicinae = {
    enable = mkEnableOption "Vicinae command palette launcher";
  };

  config = mkIf cfg.enable {
    programs.vicinae = {
      enable = true;

      # The daemon has to be up before the hotkey is useful, and it must be
      # tied to the graphical session rather than to login — niri is started
      # per session, and `graphical-session.target` is what this home-manager
      # module waits on by default.
      systemd.enable = true;

      # The Firefox integration installs a native messaging host so the
      # browser extension can drive the launcher. This is the only browser
      # integration the nixpkgs home-manager module offers; Chrome support
      # exists upstream but has not landed in this module yet.
      enableFirefoxIntegration = true;
    };
  };
}
