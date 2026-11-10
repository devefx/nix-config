{
  config,
  lib,
  pkgs,
  ...
}:
# 雾凇拼音接管中文输入：fcitx5 是框架，fcitx5-rime 是接进 fcitx5 的 librime
# 插件，rime-ice 是跑在 librime 上的方案与词库。
#
# 用户目录不能整目录软链进 store —— Rime 要往里写 *.userdb、build/ 和
# installation.yaml，只读会让部署失败、词频也学不到。所以方案和词库由
# activation 播种，用户词典走 sync 目录同步到 ~/Sync。
let
  rimeData = "${pkgs.rime-ice}/share/rime-data";
  userDataDir = "${config.xdg.dataHome}/fcitx5/rime";
  syncDir = "${config.home.homeDirectory}/Sync/rime-sync";

  # 脚本见同目录的 sync-before-start.sh：恢复缺失的 userdb、补回 user.yaml，
  # 再合并所有快照并导出新的。
  syncBeforeStart = pkgs.writeShellScript "rime-sync-before-start" (
    builtins.readFile ./sync-before-start.sh
  );
in
{
  # 引擎：rime 插件与输入法列表。
  i18n.inputMethod.fcitx5 = {
    addons = [ pkgs.fcitx5-rime ];

    # ~/.config/fcitx5 是 home-manager 生成的只读 linkFarm，fcitx5 自己写不了
    # profile，所以列表只能在这里声明，顺序也只能改这里。
    settings.inputMethod = {
      GroupOrder."0" = "Default";
      "Groups/0" = {
        Name = "Default";
        "Default Layout" = "us";
        DefaultIM = "rime";
      };
      "Groups/0/Items/0".Name = "keyboard-us";
      "Groups/0/Items/1".Name = "rime";
      "Groups/0/Items/2".Name = "pinyin";
    };
  };

  # rime_dict_manager：唯一能在 fcitx5 之外备份/恢复用户词典的工具。
  home.packages = [ pkgs.librime ];

  # nixpkgs 的 rime-ice 包没装 default.yaml，而 rime_ice.schema.yaml 写死了
  # `__include: default:/punctuator` 和 `import_preset: default` —— 缺了部署会
  # 失败。直接软链上游源码树里那份，升级 rime-ice 时自动跟随。
  xdg.dataFile."fcitx5/rime/default.yaml".source = "${pkgs.rime-ice.src}/default.yaml";

  # 对上面那份打补丁：只留全拼方案。
  xdg.dataFile."fcitx5/rime/default.custom.yaml".source = ./default.custom.yaml;

  # 同步目录软链到 Syncthing 管理的位置。force 是因为第一次切换时它还是真实
  # 目录，要先搬走再建链 —— 搬运在 rimeSyncMigrate 里。
  xdg.dataFile."fcitx5/rime/sync" = {
    source = config.lib.file.mkOutOfStoreSymlink syncDir;
    force = true;
  };

  # 第一次切换：把已有的 sync 真实目录搬进 ~/Sync，之后 sync 一直是软链。
  home.activation.rimeSyncMigrate = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    if [ -d "${userDataDir}/sync" ] && [ ! -L "${userDataDir}/sync" ]; then
      run mkdir -p "${syncDir}"
      run cp -a "${userDataDir}/sync/." "${syncDir}/"
      run rm -rf "${userDataDir}/sync"
    fi
  '';

  # 播种方案和词库。--ignore-existing 保住已有的 userdb/build/custom.yaml；
  # --chmod 让 Rime 能写 build/（store 里是 0444/0555）。
  #
  # 升级 rime-ice 后已存在的 yaml/dict 不会刷新，要强制同步就删掉再 switch
  # （别删 *.userdb，那是词频）：
  #   rm -rf ~/.local/share/fcitx5/rime/{build,*.yaml,cn_dicts,en_dicts,lua}
  home.activation.rimeSeed = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    target="${userDataDir}"
    run mkdir -p "$target" "${syncDir}"
    run ${pkgs.rsync}/bin/rsync -a --ignore-existing --chmod=Du+w,F644 \
      "${rimeData}/" "$target/"
  '';

  # 用上面那个脚本：fcitx5 每次启动前跑一次。
  systemd.user.services.fcitx5-daemon.Service.ExecStartPre = [ "${syncBeforeStart}" ];
}
