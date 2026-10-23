{
  lib,
  llama-cpp,
  fetchFromGitHub,
}:

# llama.cpp 0.7.0 on top of the nixpkgs Vulkan build.
#
# nixpkgs ships 0.6.0, so this only has to move the source and the two hashes
# that the bump invalidates. Everything else in the recipe — Vulkan support,
# the web UI's npm build, the build number and commit strings — is inherited.
#
# The reason to be here rather than on 0.6.0 is `--moe-cache-mib`: v0.7.0 can
# keep MoE experts in a GPU-side LRU cache fed from host memory, which upstream
# measures at up to ~2.2x decode throughput when experts are offloaded. That is
# exactly the Flash-Next shape.
#
# Three things had to change beyond the source hash:
#
#   patches      nixpkgs patches tests/test-llama-archs.cpp for upstream #30034.
#                v0.7.0 already contains it, so the patch reverses and the build
#                stops. Drop it.
#   npmDepsHash  tools/ui/package.json moved; the hash below is what the 0.7.0
#                tree actually produces.
#   doCheck      nixpkgs' `disabledTests` names 0.6.0 test binaries. v0.7.0
#                renamed some of them, so the network-dependent ones
#                (test-download-model among them) start running and fail in the
#                sandbox. This is a production build, so tests stay off; the
#                binary is exercised against a local GGUF instead.
#
# Drop this file once nixpkgs reaches 0.7.0.
(llama-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = "v0.7.0";
    hash = "sha256-pEDYgI3AMTU+cekvRX7NNt5wddznydQSNuerswvEpsA=";
  };

  patches = [ ];

  npmDepsHash = "sha256-hqYzdp1FwPhYkBP278fQXgY9NCKB6Q3P6Gko7BfP0m0=";

  doCheck = false;

  meta = old.meta // {
    changelog = "https://github.com/ggml-org/llama.cpp/releases/tag/v0.7.0";
  };
})
