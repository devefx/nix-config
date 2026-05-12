# Wechat for Linux, packaged as a bwrap-wrapped AppImage.
#
# Upstream AppImage is fetched via web.archive.org (stable snapshot) rather
# than the raw Tencent URL, so the hash pinning stays reproducible.
# Archive URL syntax: https://web.archive.org/web/<timestamp>if_/<original>
# (the `if_` suffix skips the Wayback toolbar injection).
#
# Refer:
# - nixpkgs package: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/we/wechat/package.nix
# - wechat-universal on AUR: https://aur.archlinux.org/cgit/aur.git/tree/wechat-universal.sh?h=wechat-universal-bwrap
{
  appimageTools,
  fetchurl,
  stdenvNoCC,
}:
let
  pname = "wechat";
  sources = {
    x86_64-linux = {
      version = "4.1.1.4";
      src = fetchurl {
        url = "https://web.archive.org/web/20260311102439if_/https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-XxAvFnlljqurGPDgRr+DnuCKbdVvgXBPh02DLHY3Oz8=";
      };
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;
  inherit (sources.${system} or (throw "Unsupported system: ${system}")) version src;

  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;

  src = appimageContents;

  extraInstallCommands = ''
    mkdir -p $out/share/applications
    cp ${appimageContents}/wechat.desktop $out/share/applications/
    mkdir -p $out/share/pixmaps
    cp ${appimageContents}/wechat.png $out/share/pixmaps/

    substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
  '';

  # Redirect WeChat's data under XDG_DOCUMENTS_DIR/WeChat_Data and jail
  # its $HOME to that dir only — upstream WeChat insists on writing all
  # over $HOME if left unchecked.
  extraPreBwrapCmds = ''
    XDG_DOCUMENTS_DIR="''${XDG_DOCUMENTS_DIR:-$(xdg-user-dir DOCUMENTS)}"
    if [[ -z "''${XDG_DOCUMENTS_DIR}" ]]; then
        echo 'Error: Failed to get XDG_DOCUMENTS_DIR, refuse to continue'
        exit 1
    fi

    WECHAT_DATA_DIR="''${XDG_DOCUMENTS_DIR}/WeChat_Data"

    WECHAT_HOME_DIR="''${WECHAT_DATA_DIR}/home"
    WECHAT_FILES_DIR="''${WECHAT_DATA_DIR}/xwechat_files"

    mkdir -p "''${WECHAT_FILES_DIR}"
    mkdir -p "''${WECHAT_HOME_DIR}"
    ln -snf "''${WECHAT_FILES_DIR}" "''${WECHAT_HOME_DIR}/xwechat_files"
  '';
  extraBwrapArgs = [
    "--tmpfs /home"
    "--tmpfs /root"
    "--bind \${WECHAT_HOME_DIR} \${HOME}"
    "--bind \${WECHAT_FILES_DIR} \${WECHAT_FILES_DIR}"
    "--chdir \${HOME}"
    # wechat-universal only supports xcb (no native wayland yet).
    "--setenv QT_QPA_PLATFORM xcb"
    "--setenv QT_AUTO_SCREEN_SCALE_FACTOR 1"
    # fcitx5 integration for Chinese input.
    "--setenv QT_IM_MODULE fcitx"
    "--setenv GTK_IM_MODULE fcitx"
  ];
  chdirToPwd = false;
  unshareNet = false;
  unshareIpc = true;
  unsharePid = true;
  unshareUts = true;
  unshareCgroup = true;
  privateTmp = true;
}
