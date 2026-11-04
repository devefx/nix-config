{
  lib,
  stdenv,
  python3,
  hactool,
}:
# Turns a Breath of the Wild dump into the folder Savage Wind Recomp sets up
# from: `exefs/` and `romfs/` for version 1.9.0.
#
# The three extractors are MacNativeGames' (MIT, Copyright (c) 2026
# MacNativeGames contributors), vendored by TotK Recomp under
# tools/vendor/macnativegames/. They already read NCA3, which is what Breath of
# the Wild uses; the two patches make them game-agnostic instead of TotK-only:
#
#   generic-title.patch  the title id comes from SW_BASE_ID / SW_UPDATE_ID, and
#                        a combined XCI's DLC and update NCAs are skipped when
#                        picking the base Program NCA
#   update-romfs.patch   extract_romfs reads the update's Program NCA, which is
#                        a BKTR patch rather than a base image
#
# provision.py drives them: exefs, then the RomFS merge (hactool combines the
# base Program NCA with the update's BKTR section), then the file tree.
let
  pythonEnv = python3.withPackages (ps: [ ps.cryptography ]);
in
python3.pkgs.buildPythonApplication {
  pname = "savage-wind-extract";
  version = "1.0.0";
  format = "other";

  src = ./.;

  patches = [
    ./generic-title.patch
    ./update-romfs.patch
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/savage-wind-extract
    cp extract_exefs.py extract_romfs.py extract_update_romfs.py provision.py \
      $out/lib/savage-wind-extract/
    makeWrapper ${pythonEnv.interpreter} $out/bin/sw-extract \
      --add-flags "$out/lib/savage-wind-extract/provision.py" \
      --prefix PYTHONPATH : "$out/lib/savage-wind-extract" \
      --prefix PATH : ${lib.makeBinPath [ hactool ]}
    runHook postInstall
  '';

  doCheck = false;

  meta = {
    description = "Extract Breath of the Wild's ExeFS and merged RomFS for Savage Wind Recomp";
    license = lib.licenses.mit;
    mainProgram = "sw-extract";
    platforms = lib.platforms.linux;
  };
}
