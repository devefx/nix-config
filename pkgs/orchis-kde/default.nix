{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  unstableGitUpdater,
}:
# Kvantum themes from vinceliuice/Orchis-kde -- the Qt sibling of the
# Orchis-theme GTK package that home/linux/gui/base/gtk.nix already selects.
#
# Only the Kvantum half is installed. The repository also carries Aurorae window
# decorations, Plasma colour schemes, desktop themes, SDDM and wallpapers, which
# only matter on Plasma; this repo runs niri, and `programs.plasma` there is
# gated off for that host (outputs/x86_64-linux/src/faex1.nix forces
# modules.desktop.plasma.enable = false for the -niri configuration).
#
# The colours in OrchisDark.kvconfig are the same numbers the GTK theme uses
# (window #212121, base #2C2C2C, alt.base #2e2e2e), so Qt apps get Orchis'
# actual widget geometry and rounded corners instead of Fusion's square
# approximations. That is the whole reason this package exists rather than
# hand-mapping the GTK palette into a qt6ct colour scheme.
stdenvNoCC.mkDerivation {
  pname = "orchis-kde";
  version = "0-unstable-2025-10-18";

  src = fetchFromGitHub {
    owner = "vinceliuice";
    repo = "Orchis-kde";
    rev = "b2a96919eee40264e79db402b915f926436100ad";
    hash = "sha256-mO1AVrnXNdg3Rftj0cQWef/RrBgSDy5kaMHagwKywEo=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # One directory per theme, each holding <Name>.kvconfig + <Name>.svg.
    # Kvantum resolves a theme as <data dir>/Kvantum/<dir>, so the package has
    # to keep this exact /share/Kvantum layout.
    install -d "$out/share/Kvantum"
    cp -a Kvantum/Orchis Kvantum/Orchis-solid "$out/share/Kvantum/"

    runHook postInstall
  '';

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    description = "Orchis theme for Kvantum (Qt sibling of the Orchis GTK theme)";
    homepage = "https://github.com/vinceliuice/Orchis-kde";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
