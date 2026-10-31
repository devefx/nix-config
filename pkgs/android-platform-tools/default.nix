{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  glibc,
}:
# Google 官方 platform-tools（预编译）。
#
# 为什么不用 nixpkgs 的 `android-tools`：那个包来自 nmeum/android-tools 的 CMake
# 移植，编译时**没有编入 mDNS 后端**，`adb mdns check` 直接报
# "mdns is not supported by this version of adb"。而 FreeControl 的「局域网扫描」
# 与「配对后解析连接端口」都依赖 `host:mdns:services`（见其 src-tauri/src/wireless.rs），
# 缺了 mDNS 这两条路直接断掉。官方 adb 自带 mDNS，故改用官方产物。
#
# 只装 adb 与 fastboot：其余工具（mke2fs、sqlite3、etc1tool、make_f2fs）都依赖
# 包内自带的 libc++.so，需要额外的 libcxx 才能 autoPatchelf，而这两个工具与手机
# 投屏/调试无关。
stdenv.mkDerivation (finalAttrs: {
  pname = "android-platform-tools";
  version = "37.0.1";

  src = fetchurl {
    url = "https://dl.google.com/android/repository/platform-tools_r${finalAttrs.version}-linux.zip";
    hash = "sha256-0jDxOEL2D3gqhkX5yBP4+EW/NgiepyifKMSPF5eTE/E=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 adb $out/bin/adb
    install -Dm755 fastboot $out/bin/fastboot
    install -Dm644 NOTICE.txt \
      $out/share/android-platform-tools/NOTICE.txt
    install -Dm644 source.properties \
      $out/share/android-platform-tools/source.properties

    runHook postInstall
  '';

  meta = {
    description = "Android SDK Platform-Tools (adb, fastboot) from Google";
    homepage = "https://developer.android.com/tools/releases/platform-tools";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "adb";
    platforms = [ "x86_64-linux" ];
  };
})
