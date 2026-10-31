{
  lib,
  pkgs,
  config,
  ...
}:
# FreeControl — scrcpy 的图形外壳（打包见 pkgs/freecontrol）。
#
# 上游把 scrcpy + adb 当作「运行环境」在首次启动后自行下载，但官方 Linux 包里的
# adb 是动态链接 glibc 的 ELF，在 NixOS 上没有 /lib64/ld-linux-x86-64.so.2，下载
# 下来也跑不起来。所以 activation 把 nixpkgs 的 scrcpy / adb 摆进应用的**约定
# 目录**：
#
#   $XDG_DATA_HOME/FreeControl2/scrcpy-linux-x86_64-v<scrcpy 版本>
#
# adb 取 Google 官方的 platform-tools 而不是 nixpkgs 的 android-tools —— 后者编译时
# 没编入 mDNS，`host:mdns:services` 会报 unknown host service，局域发现与配对后的
# 端口解析都断掉（见 pkgs/android-platform-tools）。
#
# 目录名与上游 src-tauri/src/scrcpy.rs 的 PLATFORMS 表一致（tag = linux-x86_64），
# 应用首启即判定「环境就绪」，不会触发下载。
#
# 约定目录名里带 scrcpy 版本，而应用的 BEST_FIT_VERSION 写死在它自己源码里。两者
# 一旦分叉（FreeControl 升级，或 nixpkgs 的 scrcpy 先动），应用会认为环境缺失。
# 因此另外放一份与版本无关的 `freecontrol-env`：分叉时到「运行环境」页把目录改成
# 它即可，不必再改 Nix。
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.freeControl;

  freecontrol = pkgs.callPackage ../../../../pkgs/freecontrol { };
  androidPlatformTools = pkgs.callPackage ../../../../pkgs/android-platform-tools { };

  # 与版本无关的运行环境：只有 scrcpy 与 adb 两个可执行文件，正是应用
  # assets::REQUIRED_BINS 要求的那两个名字。
  freecontrolEnv = pkgs.runCommand "freecontrol-env-${pkgs.scrcpy.version}" { } ''
    mkdir -p $out
    ln -s ${pkgs.scrcpy}/bin/scrcpy $out/scrcpy
    ln -s ${androidPlatformTools}/bin/adb $out/adb
  '';

  envDir = "${config.xdg.dataHome}/FreeControl2/scrcpy-linux-x86_64-v${pkgs.scrcpy.version}";
in
{
  options.modules.freeControl = {
    enable = mkEnableOption "FreeControl (scrcpy GUI for Android devices)";
  };

  config = mkIf cfg.enable {
    home.packages = [ freecontrol ];

    xdg.dataFile."freecontrol-env".source = freecontrolEnv;

    # 约定目录做成普通目录 + 两个 store 符号链接，而不是整目录的符号链接：应用要
    # 「替换运行环境」时得能删目录里的内容，指向 store 的目录链接会挡住它。
    home.activation.freeControlRuntime = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      envDir="${envDir}"
      run mkdir -p "$envDir"
      run ln -sfn ${pkgs.scrcpy}/bin/scrcpy "$envDir/scrcpy"
      run ln -sfn ${androidPlatformTools}/bin/adb "$envDir/adb"
    '';
  };
}
