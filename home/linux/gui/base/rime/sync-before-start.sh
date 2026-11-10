# fcitx5 启动前跑：恢复缺失的用户数据，再把本地词典导出成新快照。
#
# 必须在 ExecStartPre —— 同步要写 LevelDB，fcitx5 运行时数据库被锁，命令行
# rime_dict_manager 必然失败。rime_dict_manager 由 home.packages 提供。
set -u

target="$HOME/.local/share/fcitx5/rime"
[ -d "$target/sync" ] || exit 0

# 1. 本地还没有的 userdb，先从备份里恢复（重装系统后的情形）。
for snapshot in "$target"/sync/*/*.userdb.txt; do
  [ -e "$snapshot" ] || continue
  file=${snapshot##*/}
  name=${file%.userdb.txt}
  [ -d "$target/$name.userdb" ] && continue
  ( cd "$target" && rime_dict_manager -r "$snapshot" ) || true
done

# 2. user.yaml 存的是方案选择和开关状态，不是 LevelDB，直接拷最新一份。
#    不拷的话它会被 Rime 重建成默认值，旧状态反而会被下次部署盖掉。
if [ ! -f "$target/user.yaml" ]; then
  latest=$(ls -t "$target"/sync/*/user.yaml 2>/dev/null | head -1)
  [ -n "$latest" ] && cp "$latest" "$target/user.yaml"
fi

# 3. 合并已有的快照（重装后接上旧习惯），再把本地导出成新快照。
( cd "$target" && rime_dict_manager -s ) || true
