{
  lib,
  pkgs,
  config,
  ...
}:
# Motrix — full-featured download manager (HTTP / FTP / BitTorrent / magnet)
# built on aria2. Packaged from the upstream AppImage in `pkgs/motrix`
# because nixpkgs still ships the pre-rewrite 1.8.19 release.
#
# Gated behind `modules.motrix.enable` — enable in
# `home/hosts/<name>.nix`.
#
# 关闭主窗口只是把它 hide 到托盘（上游 `main` 窗口的 closeBehavior 是 "hide"），
# 进程和 aria2 都继续跑。再次点图标时新进程走 Electron 的单实例转发，主进程收到
# `second-instance` 后调用 `BrowserWindow.show()` + `focus()`。问题在于 Wayland
# 下 Chromium 不会给这次激活带上 xdg-activation token，niri 于是把窗口放回原来
# 的列，却不滚动视图、也不改焦点 —— 看起来就是「点了没反应」。所以这里包一层
# 启动器：先按原样启动（或转发给已有实例），再让 niri 自己把窗口聚焦过来。
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.motrix;

  motrix = pkgs.callPackage ../../../../pkgs/motrix { };

  motrixLauncher = pkgs.writeShellApplication {
    name = "motrix";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      if [[ -z "''${NIRI_SOCKET:-}" ]] || ! command -v niri >/dev/null 2>&1; then
        exec "${lib.getExe motrix}" "$@"
      fi

      # 已有实例时这个进程只是转发链接/种子然后退出；没有实例时它就是主进程。
      # 不开 setsid：niri 的 app scope 以这里为 leader，wrapper 退出会连带杀掉
      # 它启动的 Motrix。
      "${lib.getExe motrix}" "$@" &
      child=$!

      # 带链接/种子启动时优先聚焦「新建任务」窗口，否则聚焦主窗口。
      pick_window() {
        niri msg --json windows 2>/dev/null |
          jq -r '
            [.[] | select((.app_id // "") == "motrix")]
            | (map(select(.title == "New Task")) + map(select(.title != "New Task")))
            | first | .id // empty
          ' 2>/dev/null || true
      }

      # 冷启动要等 Electron 把窗口映射出来，已有实例则几乎立刻就有。
      window_id=""
      for _ in {1..100}; do
        window_id="$(pick_window)"
        [[ -n "$window_id" ]] && break
        sleep 0.1
      done

      if [[ -n "$window_id" ]]; then
        # 让「新建任务」窗口先映射完，别把焦点又抢回主窗口。
        sleep 0.3
        window_id="$(pick_window)"
        if [[ -n "$window_id" ]]; then
          niri msg action focus-window --id "$window_id" >/dev/null 2>&1 || true
        fi
      fi

      wait "$child" 2>/dev/null || true
    '';
  };
in
{
  options.modules.motrix = {
    enable = mkEnableOption "Motrix download manager";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # symlinkJoin 保留 pkgs/motrix 的 desktop 文件和图标，只把 bin/motrix 换成
      # 上面的启动器；desktop 里的 `Exec=motrix %U` 因此解析到启动器。
      (pkgs.symlinkJoin {
        name = "motrix";
        paths = [ motrix ];
        postBuild = ''
          rm "$out/bin/motrix"
          ln -s ${motrixLauncher}/bin/motrix "$out/bin/motrix"
        '';
      })
    ];
  };
}
