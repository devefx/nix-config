{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  adwaita-icon-theme,
  dbus,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  libsoup_3,
  openssl,
  webkitgtk_4_1,
  xdg-utils,
}:
# FreeControl — scrcpy 的图形外壳（Tauri 2 + Svelte，控制 Android 设备投屏）。
#
# 上游 Linux 有两种产物：AppImage（83 MB，把 WebKitGTK 4.1 整套打进包里）与 deb
# （3.2 MB，只声明 `libwebkit2gtk-4.1-0, libgtk-3-0`）。这里取 deb —— 与
# pkgs/hongguo-tv、pkgs/cc-switch 同一条理由：内嵌的 WebKitGTK 在 NixOS 上会因为
# 库路径与 EGL 不匹配而白屏，链接系统的 webkitgtk_4_1 才是可复现的路径。
#
# 运行环境（scrcpy + adb）不在本包里 —— 上游刻意不随安装包分发，首次启动后由应用
# 自行下载。官方 Linux 包里的 adb 是动态链接 glibc 的 ELF，在 NixOS 上没有
# /lib64/ld-linux-x86-64.so.2 跑不起来，所以 home/linux/gui/base/freecontrol.nix 会
# 把 nixpkgs 的 scrcpy / adb 摆进应用的约定目录。
stdenv.mkDerivation (finalAttrs: {
  pname = "freecontrol";
  version = "2.3.2";

  src = fetchurl {
    url = "https://github.com/pdone/FreeControl/releases/download/v${finalAttrs.version}/FreeControl_${finalAttrs.version}_linux_amd64.deb";
    hash = "sha256-+c1Q+zPPTozqrz8yvy6fM8NuUTSXpLcEHAZi7Rs64eQ=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    # DT_NEEDED 的 libgcc_s.so.1；autoPatchelfHook 不递归解析传递依赖。
    stdenv.cc.cc.lib
    dbus
    gtk3
    libsoup_3
    openssl
    webkitgtk_4_1
    # TLS（libsoup 3 经 GIO 找 TLS 模块）、GTK 3 运行期要的 schemas 与图标主题。
    glib-networking
    gsettings-desktop-schemas
    adwaita-icon-theme
  ];

  # stdenv 没有 .deb 的解包钩子。
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  # 打包由 wrapGApp 在 postFixup 里手工完成（见下），故不让钩子自己 wrap。
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/${finalAttrs.pname} $out/bin $out/share
    install -Dm755 usr/bin/FreeControl $out/libexec/${finalAttrs.pname}/FreeControl

    cp -r usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/FreeControl.desktop \
      $out/share/applications/FreeControl.desktop

    runHook postInstall
  '';

  postFixup = ''
    # 「打开目录 / 打开日志」走 open crate，Linux 上即 xdg-open。
    wrapGApp $out/libexec/${finalAttrs.pname}/FreeControl \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}

    ln -s $out/libexec/${finalAttrs.pname}/FreeControl $out/bin/FreeControl
  '';

  meta = {
    description = "GUI launcher for scrcpy — control Android devices from the PC";
    homepage = "https://github.com/pdone/FreeControl";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "FreeControl";
    platforms = [ "x86_64-linux" ];
  };
})
