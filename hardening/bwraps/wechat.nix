# Wechat for Linux, packaged as a bwrap-wrapped AppImage.
#
# Upstream AppImage content is pinned by hash so the moving Tencent URL stays
# reproducible.
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
      version = "4.1.13.9";
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-ay4g5wAGNy6N37rkDqhkVkUgyHsH0BYLYA7JP3j9XMI=";
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

    substituteInPlace $out/share/applications/wechat.desktop \
      --replace-fail AppRun wechat \
      --replace-fail 'Categories=Utility;' 'Categories=InstantMessaging;Network;'
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
    # wxutility needs libbz2.so.1.0 from the FHS environment.
    "--setenv LD_LIBRARY_PATH /usr/lib64"
    # 4.1.13.9 supports Wayland; prefer it so screenshots use the portal and
    # fall back to xcb for plugins that still require X11.
    "--setenv QT_QPA_PLATFORM 'wayland;xcb'"
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
