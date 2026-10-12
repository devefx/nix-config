{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
# llama.cpp built with the Vulkan backend. On faex1 this uses RADV via
# the AMD Radeon 8060S iGPU; the `render` group is added at the system
# level so the user can access /dev/dri/renderD128.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.llamaCpp;

  # The pinned nixpkgs still ships llama.cpp 0.4.0. Upstream's 0.4.0 -> 0.6.0
  # bump touches `version`, `src`, `buildNumber`, `buildCommit` and
  # `npmDepsHash` -- the web UI's package.json moved (tailwind-variants
  # 3.2.2 -> 3.3.1), which drags the npm dependency hash along. Overriding
  # exactly those is equivalent to moving the nixpkgs pin, without pulling in
  # the new GCC 16 stdenv, which currently cannot build `breakpad` (a
  # build-time dependency of noctalia-qs) anywhere, Hydra included.
  #
  # Deliberately not carried over from upstream's 0.6.0 recipe: the test
  # enablement (doCheck, ctestCheckHook, python3 and the test-llama-archs
  # patch) and the GGML_BACKEND_DIR flag. The pinned 0.4.0 recipe keeps
  # doCheck = false, so tests are neither built nor run and the patch would be
  # dead weight.
  #
  # Drop this override once nixpkgs is bumped again.
  llama-cpp = pkgs.llama-cpp-vulkan.overrideAttrs (old: {
    version = "0.6.0";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "v0.6.0";
      hash = "sha256-l6l6JIlIVTaVC6xh5M4fRHFtXsweQuugtkNTWHcZZF4=";
    };
    npmDepsHash = "sha256-a17M+L3nLdRnN6WMB6imPFmwqG2g8uv+gwN0XTAUrf8=";
    preConfigure =
      lib.replaceStrings [ "LLAMA_BUILD_NUMBER=10809" ] [ "LLAMA_BUILD_NUMBER=11429" ]
        old.preConfigure;
    cmakeFlags = map (
      flag:
      lib.replaceStrings
        [ "-DLLAMA_BUILD_NUMBER:STRING=10809" "-DLLAMA_BUILD_COMMIT:STRING=5266f24" ]
        [ "-DLLAMA_BUILD_NUMBER:STRING=11429" "-DLLAMA_BUILD_COMMIT:STRING=d812350" ]
        flag
    ) old.cmakeFlags;
  });
in
{
  options.modules.llamaCpp = {
    enable = mkEnableOption "llama.cpp with Vulkan backend";
  };

  config = mkIf cfg.enable {
    home.packages = [
      llama-cpp
    ];

    programs.bash.profileExtra = lib.mkIf (osConfig.modules.secrets.hf.enable or false) ''
      export HF_TOKEN="$(cat ${osConfig.age.secrets.hf-token.path} 2>/dev/null)"
    '';
  };
}
