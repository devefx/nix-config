{
  lib,
  appimageTools,
  fetchurl,
}:
# Motrix — full-featured download manager (HTTP / FTP / BitTorrent / magnet)
# built on aria2. Upstream only ships a Linux x86_64 AppImage.
#
# nixpkgs still packages 1.8.19, the pre-rewrite Electron app from 2023.
# Upstream 2.x ("motrix-turbo") is a substantial rewrite, so this override
# tracks the current release instead. The AppImage layout is unchanged from
# 1.8.19: AppRun + the Electron payload live at the AppDir root, and the
# desktop file / icon sit next to them rather than under `usr/share`.
#
# To bump: update `version`, then refresh the hash with
#   nix store prefetch-file --json <AppImage URL>
# (the `hash` field in the JSON output is already SRI).
let
  version = "2.1.0";

  src = fetchurl {
    url = "https://github.com/agalwood/Motrix/releases/download/v${version}/Motrix-${version}-x86_64.AppImage";
    hash = "sha256-lZoAuq9v2YLLnbPmNZvuhmw8sg6hJFQbIScKoksdL4E=";
  };
in
appimageTools.wrapType2 (finalAttrs: {
  pname = "motrix";
  inherit version src;

  extraInstallCommands = ''
    install -Dm444 ${finalAttrs.contents}/motrix.desktop \
      $out/share/applications/motrix.desktop
    install -Dm444 ${finalAttrs.contents}/motrix.png \
      $out/share/icons/hicolor/512x512/apps/motrix.png

    # The upstream entry launches `AppRun`; inside the FHS wrapper that name
    # only exists in the extracted AppDir, so point it at the wrapper instead.
    substituteInPlace $out/share/applications/motrix.desktop \
      --replace-quiet 'Exec=AppRun' 'Exec=motrix'
  '';

  meta = {
    description = "Full-featured download manager";
    homepage = "https://motrix.app";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "motrix";
    platforms = [ "x86_64-linux" ];
  };
})
