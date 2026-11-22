{
  config,
  lib,
  pkgs,
  myvars ? { },
  ...
}:
# Hookshot — 塞尔达传说：时之笛（Switch 2 重制版）的静态重编译。
#
# 和 savage-wind / totk 同一套模式：声明 URL → systemd oneshot 准备 → 结果落在
# 可写 stateDir，Nix 只管引擎。区别是上游 AppImage 自带整套构建器（Python、
# clang 23、glibc 2.35 sysroot、FFmpeg、SDL2 和 Vulkan 后端的源码），所以这里
# 不用自己解包、patchelf，而是让 `appimage-run` 在 bwrap 的 FHS 环境里执行：
#
#   Hookshot-<ver>-x86_64.AppImage --cli --game <dump> --prepare --out <dir>
#
# 一次构建 10–45 分钟（视 CPU/内存而定），产出 `<dir>/bin/hookshot` 和启动器。
# 末尾的着色器准备失败不算构建失败——上游的语义是把这份工作留给首次启动。
# `hookshot-provision --check` 只验证 dump 的版本（不构建），`--force` 忽略
# `.built` 戳重建。
#
# 必须自备 Switch 2 版 dump：程序 id 0400486024DEC000、更新 v131072、build
# e0f3ccfa，形态是 `.nup`（或 NXFormat 转出的 `.nx`，或含 romfs/exefs 的
# 文件夹）。它是游戏内容，默认从 `stateDir/source` 读取，不进 Nix store。
#
# 上游 GitHub 仓库 2026-11-13 被任天堂下架，现托管在 git.notrexed.dev，
# 所以 appImage 故意不给默认值：URL 会变，在主机里写死并配 hash。
let
  inherit (lib)
    escapeShellArg
    mkEnableOption
    mkIf
    mkOption
    optionalString
    types
    ;

  cfg = config.modules.desktop.hookshot;

  # fetchurl 落进 store 是 0444，AppImage 需要可执行位才能被 appimage-run 读。
  appImage = pkgs.runCommand "hookshot-appimage-${cfg.version}" { } ''
    install -Dm755 ${pkgs.fetchurl { inherit (cfg.appImage) url hash; }} $out/bin/Hookshot.AppImage
  '';

  # 菜单的中文字形 = 游戏自带字体的子集 + 系统 Noto CJK。Linux 上系统字体是写死
  # 的 Debian/Arch/Fedora 路径（`gpu/vk/vk_imgui.cpp` 的 CJK_LINUX）：
  #
  #   /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
  #
  # NixOS 的字体在 store 里、文件名是 `NotoSansCJK-VF.otf.ttc`，appimage-run 的
  # FHS 里又没有那个路径，游戏字体子集以外的字就变成 `?`。这里给 FHS 多装一个
  # 只提供这条路径的兼容包；它只要求文件存在且 FreeType 能读，所以直接链到 VF
  # 那份 ttc 就够。
  notoCjkCompat = pkgs.runCommand "noto-cjk-hookshot-compat" { } ''
    mkdir -p $out/share/fonts/opentype/noto
    ln -s ${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc \
      $out/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
  '';

  # `appimage-run` 本体就是 buildFHSEnv，`extraPkgs` 会并进 FHS 的 `/usr/share`，
  # 其余（bwrap 对 /home、/mnt、/var 的绑定、X11/Wayland）与上游一致。
  appimageRun = pkgs.appimage-run.override { extraPkgs = _: [ notoCjkCompat ]; };

  # `path` 优先：`.nup` 是游戏内容，走 fetchurl 会复制进世界可读的 Nix store，
  # 和 savage-wind 的 ROM 是同一个取舍。
  gameSource =
    if cfg.source.path != null then
      cfg.source.path
    else if cfg.source.url != null then
      "${pkgs.fetchurl { inherit (cfg.source) url hash; }}"
    else
      null;

  gameDir = "${cfg.stateDir}/game";

  # 只动 `settings` 里点名的键：ini 也是游戏自己写的（分辨率、手柄布局、画面
  # 选项），其余键保持玩家在游戏里改的样子。
  settingsScript = lib.concatStrings (
    lib.mapAttrsToList (key: value: ''
      if grep -q '^${key}=' "$out/hookshot_options.ini" 2>/dev/null; then
        sed -i 's|^${key}=.*|${key}=${toString value}|' "$out/hookshot_options.ini"
      else
        echo '${key}=${toString value}' >> "$out/hookshot_options.ini"
      fi
    '') cfg.settings
  );

  provisionScript = pkgs.writeShellApplication {
    name = "hookshot-provision";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      force=0
      check=0
      case "''${1:-}" in
        --force) force=1 ;;
        --check) check=1 ;;
      esac

      game=${escapeShellArg (if gameSource == null then "" else toString gameSource)}
      out=${escapeShellArg gameDir}
      stamp=${escapeShellArg "${cfg.stateDir}/.built"}

      ${optionalString (cfg.memLimitGb != null) ''
        export HOOKSHOT_MEM_LIMIT_GB=${toString cfg.memLimitGb}
      ''}

      if [ -z "$game" ]; then
        echo "hookshot-provision: 没有声明游戏文件；设置 modules.desktop.hookshot.source.path（或 .url/.hash）" >&2
        exit 0
      fi
      if [ ! -e "$game" ]; then
        echo "hookshot-provision: $game 不存在，跳过；放好 .nup 后 systemctl start hookshot-provision" >&2
        exit 0
      fi

      if [ "$check" -eq 1 ]; then
        exec ${appimageRun}/bin/appimage-run ${appImage}/bin/Hookshot.AppImage --cli \
          --check \
          --game "$game"
      fi

      want=${escapeShellArg "${cfg.version}|${cfg.language}|"}''${game}
      if [ "$force" -eq 0 ] && [ -x "$out/bin/hookshot" ] && [ "$(cat "$stamp" 2>/dev/null || true)" = "$want" ]; then
        echo "hookshot-provision: 已构建（$(du -sh "$out" | cut -f1)）；--force 强制重建"
        exit 0
      fi

      echo "hookshot-provision: 从 $game 构建到 $out，预计 10–45 分钟"
      mkdir -p "$(dirname "$out")"
      ${appimageRun}/bin/appimage-run ${appImage}/bin/Hookshot.AppImage --cli \
        --game "$game" \
        --out "$out" \
        --prepare \
        --language ${escapeShellArg cfg.language} \
        ${optionalString (cfg.jobs != null) "--jobs ${toString cfg.jobs}"}
      ${settingsScript}
      echo "$want" > "$stamp"
    '';
  };

  launcher = pkgs.writeShellApplication {
    name = "hookshot";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      out=${escapeShellArg gameDir}
      if [ ! -x "$out/bin/hookshot" ]; then
        echo "hookshot: 游戏还没构建；先跑 sudo systemctl start hookshot-provision" >&2
        exit 1
      fi
      exec ${appimageRun}/bin/appimage-run ${appImage}/bin/Hookshot.AppImage --play "$out" "$@"
    '';
  };

  icon = pkgs.runCommand "hookshot-icon" { } ''
    install -Dm644 ${../../../assets/hookshot/icon.png} $out/share/pixmaps/hookshot.png
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "hookshot";
    desktopName = "塞尔达传说：时之笛";
    genericName = "The Legend of Zelda: Ocarina of Time (Switch 2 remake)";
    comment = "Ocarina of Time (Switch 2), statically recompiled to native code";
    exec = "hookshot";
    icon = "hookshot";
    categories = [ "Game" ];
    startupNotify = false;
    singleMainWindow = true;
  };
in
{
  options.modules.desktop.hookshot = {
    enable = mkEnableOption "Hookshot (Ocarina of Time, Switch 2 remake)";

    version = mkOption {
      type = types.str;
      default = "2.3.2";
      description = "上游 release tag，只用于 store 路径名。";
    };

    appImage = mkOption {
      type = types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            description = ''
              上游的 `Hookshot-v<version>-x86_64.AppImage`。钉死具体 tag，别用
              `releases/latest`：上游 asset 会被替换，hash 就对不上了。
            '';
          };
          hash = mkOption {
            type = types.str;
            description = "AppImage 的 SRI hash，`nix hash file` 的输出。";
          };
        };
      };
      description = "上游 AppImage（自带构建器、Python、clang 和 sysroot）。";
    };

    source = mkOption {
      type = types.submodule {
        options = {
          path = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              本地 `.nup`/`.nx` 文件或含 romfs/exefs 的文件夹的绝对路径。优先于
              `url`，因为它不会把游戏内容复制进世界可读的 Nix store。
            '';
          };
          url = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "也可以给 URL（会同 savage-wind 的 ROM 一样进 store）。";
          };
          hash = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "配合 `url` 使用的 SRI hash。";
          };
        };
      };
      default = { };
      description = "你自己的 Switch 2 版 OoT 重制版 dump。";
    };

    language = mkOption {
      type = types.str;
      default = "zh-Hans";
      description = ''
        游戏语言，写进游戏文件夹的 `language.txt`。上游支持：en-US、en-GB、
        fr、fr-CA、de、it、es、es-419、pt-BR、nl、pl、ru、ja、ko、zh-Hans、
        zh-Hant。
      '';
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/hookshot";
      description = ''
        可写状态：`game/`（构建产物、存档和设置）、`source/`（你的 dump）和
        `.built` 戳。游戏文件夹整个在这里，重建不会碰存档。
      '';
    };

    user = mkOption {
      type = types.str;
      default = myvars.username or "nobody";
      description = "`stateDir` 的属主；构建和游戏都以这个用户运行。";
    };

    jobs = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "同时编译的文件数，透传给 `--jobs`。默认让上游按 CPU/内存自己定。";
    };

    memLimitGb = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "编译器的内存上限（GB），设为 `HOOKSHOT_MEM_LIMIT_GB`。";
    };

    settings = mkOption {
      type = types.attrsOf (types.either types.int types.str);
      default = { };
      example = {
        dlss = 3;
        resolution = 3;
        frame_rate_cap = 0;
        fps_counter = 1;
      };
      description = ''
        每次 provision 之后写进 `hookshot_options.ini` 的键值，只覆盖这里点名的
        键。键名和游戏内菜单对应：`dlss` 是 Upscaler（3 = AMD FSR 3.1）、
        `resolution` 是 Render resolution（1..6 = 100/75/67/50/58/33%）、
        `texture_detail`（0 Auto、1 Full、2 Medium、3 Low）、`frame_rate_cap`
        （0 = 60、1 = 90、…、5 = 240、6 = Uncapped）、`fps_counter`
        （0 关、1 FPS、2 Frame time、3 Graph、4 Breakdown）。
      '';
    };
  };

  config = mkIf cfg.enable {
    # 构建 10–45 分钟，所以挂在 multi-user 上并行跑，不挡 graphical.target；
    # 没有声明 dump 时脚本自己跳过，不会让开机失败。
    systemd.services.hookshot-provision = {
      description = "Build the Hookshot game folder from the user's own dump";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
        # appimage-run 把 AppImage 解包进 ~/.cache/appimage-run，构建器的工具
        # 缓存也在 HOME 下，所以这两个变量必须在服务里给全。
        Environment = [
          "HOME=${config.users.users.${cfg.user}.home}"
          "XDG_CACHE_HOME=${config.users.users.${cfg.user}.home}/.cache"
        ];
      };
      script = "${provisionScript}/bin/hookshot-provision";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
      "d ${cfg.stateDir}/source 0700 ${cfg.user} ${config.users.users.${cfg.user}.group} -"
    ];

    environment.systemPackages = [
      launcher
      desktopItem
      icon
      provisionScript
    ];
  };
}
