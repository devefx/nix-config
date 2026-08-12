{
  lib,
  stdenv,
  cmake,
  zlib,
  fetchFromGitHub,
}:

stdenv.mkDerivation rec {
  pname = "was-thumbnail-provider";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "MHGameDevs";
    repo = "was_thumbnail_provider";
    rev = "4c218c27140fd35a7d4a5f6af156039f5ae14c7f";
    sha256 = "sha256-fpenpWtwZ9aSuP/gpVV+/ZexppQ2Tin3/9+RiF+Xg+E=";
  };

  nativeBuildInputs = [ cmake ];
  buildInputs = [ zlib ];

  cmakeFlags = [
    "-DWAS_BUILD_LINUX_CLI=ON"
    "-DWAS_BUILD_WINDOWS_SHELL=OFF"
  ];

  doCheck = true;

  postInstall = ''
    substituteInPlace "$out/share/thumbnailers/was-thumbnail-provider.thumbnailer" \
      --replace-fail "Type=X-WAS" "Type=X-Thumbnailer" \
      --replace-fail "Exec=/usr/local/bin/was-thumbnail-provider" "Exec=$out/bin/was-thumbnail-provider" \
      --replace-fail "TryExec=was-thumbnail-provider" "TryExec=$out/bin/was-thumbnail-provider"
  '';

  meta = {
    description = "XDG thumbnail provider for WAS image files";
    homepage = "https://github.com/MHGameDevs/was_thumbnail_provider";
    mainProgram = "was-thumbnail-provider";
    platforms = lib.platforms.linux;
  };
}
