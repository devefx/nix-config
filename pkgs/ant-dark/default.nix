{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "ant-dark-plasma";
  version = "0-unstable-2026-03-24";

  src = fetchFromGitHub {
    owner = "EliverLara";
    repo = "Ant";
    rev = "79ddc06b40ad1e96c87d9270c71d7db3bfa0c3cd";
    hash = "sha256-dAx05R9QWkDcuzJF/GUhK2R7hGjY7JvtTyXEDpE+p5E=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/plasma/desktoptheme"
    cp -a "$src/kde/Dark/plasma/desktoptheme/Ant-Dark" \
      "$out/share/plasma/desktoptheme/Ant-Dark"
    runHook postInstall
  '';

  meta = {
    description = "Ant-Dark Plasma desktop theme";
    homepage = "https://store.kde.org/p/1464321";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.linux;
  };
}
