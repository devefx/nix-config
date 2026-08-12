{
  lib,
  pkgs,
  makeBinaryWrapper,
  stdenvNoCC,
  withManager ? false,
}:

# ComfyUI pinned to the same source/version as nixpkgs, but with PyTorch
# built for AMD ROCm instead of the default CPU-only torch.
let
  # Use a clean nixpkgs instance so torchWithRocm keeps its cached store
  # path; overriding through the home-manager package scope would rebuild it.
  torchRocm = (import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
  }).python3Packages.torchWithRocm;

  appDependencies =
    ps:
    with ps;
    [
      aiohttp
      alembic
      av
      blake3
      comfy-aimdo
      comfy-angle
      comfy-kitchen
      comfyui-embedded-docs
      comfyui-frontend-package
      comfyui-workflow-templates
      einops
      filelock
      kornia
      numpy
      pillow
      psutil
      pydantic
      pydantic-settings
      pyopengl
      pyyaml
      requests
      safetensors
      scipy
      sentencepiece
      simpleeval
      spandrel
      sqlalchemy
      tokenizers
      torch
      torchaudio
      torchsde
      torchvision
      tqdm
      transformers
      yarl
    ]
    ++ lib.optionals withManager [ ps.comfyui-manager ];

  pythonPackages = pkgs.python3Packages.overrideScope (
    _final: _prev: {
      torch = torchRocm;
    }
  );

  pythonPath = pythonPackages.makePythonPath (appDependencies pythonPackages);
in
stdenvNoCC.mkDerivation {
  pname = "comfyui-rocm";
  version = pkgs.comfyui.version;

  src = pkgs.comfyui.src;
  dontUnpack = true;

  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    makeBinaryWrapper ${lib.getExe pythonPackages.python} $out/bin/comfyui \
      --add-flags "${pkgs.comfyui}/share/comfyui/main.py" \
      --set PYTHONPATH "${pythonPath}" \
      --unset NIX_PYTHONPATH

    runHook postInstall
  '';

  passthru = {
    inherit pythonPackages pythonPath;
  };

  meta = pkgs.comfyui.meta // {
    description = "ComfyUI with ROCm PyTorch for AMD gfx1151 (Radeon 8060S)";
  };
}
