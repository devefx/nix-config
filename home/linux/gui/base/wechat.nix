{
  lib,
  pkgs,
  config,
  ...
}:
# Sandboxed WeChat (Linux AppImage wrapped in bwrap). Package is defined
# in `hardening/bwraps/wechat.nix` and exposed as `pkgs.bwraps.wechat`.
#
# Gated behind `modules.wechat.enable` — hosts that don't need WeChat
# skip the ~300MB AppImage closure. Chat data lands in
# `~/Documents/WeChat_Data/` (the bwrap wrapper fakes HOME to that dir).
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.wechat;

  wechatLauncher = pkgs.writeShellApplication {
    name = "wechat";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      if [[ -n "''${NIRI_SOCKET:-}" ]] && command -v niri >/dev/null 2>&1; then
        window_id="$(
          niri msg --json windows 2>/dev/null |
            jq -r '[.[] | select((.app_id // "") == "wechat")] | first | .id // empty' 2>/dev/null
        )" || true

        if [[ -n "$window_id" ]]; then
          niri msg action focus-workspace "3chat" >/dev/null 2>&1 || true
          niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
          exit 0
        fi

        niri msg action focus-workspace "3chat" >/dev/null 2>&1 || true
      fi

      exec ${lib.getExe pkgs.bwraps.wechat} "$@"
    '';
  };

  wechatDesktop = pkgs.runCommand "wechat-desktop" { } ''
    mkdir -p $out/share/applications $out/share/pixmaps
    cp ${pkgs.bwraps.wechat}/share/applications/wechat.desktop $out/share/applications/
    cp ${pkgs.bwraps.wechat}/share/pixmaps/wechat.png $out/share/pixmaps/
  '';
in
{
  options.modules.wechat = {
    enable = mkEnableOption "sandboxed WeChat (Linux AppImage via bwrap)";
  };

  config = mkIf cfg.enable {
    home.packages = [
      wechatLauncher
      wechatDesktop
    ];

    # WeChat's AppImage writes its own autostart entry on first launch, but that
    # file is unmanaged: it is a plain file in ~/.config/autostart, it carries
    # the `X-AppImage-Version` of whichever build wrote it, and if it is ever
    # removed nothing puts it back. Take it over the same way the QQ module
    # does, so the entry survives rebuilds and points at the store path.
    #
    # `${wechatDesktop}`'s desktop file already has `Exec=wechat %U` --
    # hardening/bwraps/wechat.nix substitutes `AppRun` for `wechat` -- which
    # resolves to `wechatLauncher` on PATH, so the focus-existing-window logic
    # is what actually runs.
    xdg.configFile."autostart/wechat.desktop" = {
      source = "${wechatDesktop}/share/applications/wechat.desktop";
      force = true;
    };
  };
}
