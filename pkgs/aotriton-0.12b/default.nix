{
  autoPatchelfHook,
  fetchurl,
  lib,
  rocmPackages,
  stdenv,
  xz,
}:

stdenv.mkDerivation {
  pname = "aotriton";
  version = "0.12b";

  srcs = [
    (fetchurl {
      url = "https://github.com/ROCm/aotriton/releases/download/0.12b/aotriton-0.12b-manylinux_2_28_x86_64-rocm7.2-shared.tar.gz";
      hash = "sha256-W5fo0EGxYMhAhZYfPTvXuYkGQrFGussEyZGqmtao3Kg=";
    })
    (fetchurl {
      url = "https://github.com/ROCm/aotriton/releases/download/0.12b/aotriton-0.12b-images-amd-gfx115x.tar.gz";
      hash = "sha256-MXc4ehXGeLMAV/RYTR/BuPjbVhY4kMtcmPJ0UCCfWns=";
    })
  ];

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    rocmPackages.clr
    stdenv.cc.cc.lib
    xz
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir aotriton
    for source in $srcs; do
      tar -xzf "$source" --strip-components=1 -C aotriton
    done
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    cp -a aotriton/. "$out/"
    runHook postInstall
  '';

  meta = {
    description = "ROCm Ahead of Time (AOT) Triton Math Library";
    homepage = "https://github.com/ROCm/aotriton";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
