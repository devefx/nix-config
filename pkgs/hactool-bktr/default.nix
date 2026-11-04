{
  lib,
  stdenv,
  fetchFromGitHub,
}:
# SciresM/hactool, patched for NCA3 + BKTR cumulative updates.
#
# The stock 1.4.0 release reads NCA3 headers fine, but its BKTR layout check
# rejects the subsection layout newer cumulative updates use ("Invalid BKTR
# layout!"), so it cannot merge an update's RomFS into a base NCA. The two
# patches below are the Linux-relevant ones from TotK Recomp's tools/hactool/
# (MIT, from MacNativeGames' build_app.py); its unicode.patch only adds a
# Windows manifest and is not needed here.
stdenv.mkDerivation {
  pname = "hactool-bktr";
  version = "1.4.0-unstable-1d64a83";

  src = fetchFromGitHub {
    owner = "SciresM";
    repo = "hactool";
    rev = "1d64a83450e025622f3468c28fc4164dad2c5ef6";
    hash = "sha256-PzZ1QAbgyXAjWQ0OEM1cbcojSUdfCLpEggxjWBe6vlY=";
  };

  patches = [
    ./portable.patch
    ./mbedtls-asm-clobbers.patch
  ];

  postPatch = ''
    cp config.mk.template config.mk
    substituteInPlace config.mk \
      --replace-fail "CC = gcc" "CC = ${stdenv.cc.targetPrefix}cc"
  '';

  # The vendored mbedtls 2.6.1 predates the warnings modern compilers emit.
  env.NIX_CFLAGS_COMPILE = "-Wno-error";

  enableParallelBuilding = true;

  buildPhase = ''
    runHook preBuild
    make -C mbedtls lib
    make hactool
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hactool $out/bin/hactool
    runHook postInstall
  '';

  meta = {
    description = "Nintendo Switch NCAs/ROMs tool, patched for NCA3 and BKTR updates";
    homepage = "https://github.com/SciresM/hactool";
    license = lib.licenses.isc;
    mainProgram = "hactool";
    platforms = lib.platforms.linux;
  };
}
