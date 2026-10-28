{ pkgs, ... }:
{
  # btop — fancy htop replacement. Generates ~/.config/btop/btop.conf.
  programs.btop = {
    enable = true;
    # btop's AMD support dlopen()s "librocm_smi64.so" at runtime. nixpkgs only
    # adds rocm-smi to btop's RPATH when rocmSupport is on, and without it the
    # bare soname never resolves on NixOS, so AMD GPUs are silently skipped.
    package = pkgs.btop.override { rocmSupport = true; };
    settings = {
      # Use terminal's background instead of btop's dark bg —
      # lets transparent terminals show through.
      theme_background = false;
      # Inline the GPU row in the CPU box. Do NOT put "gpu0" in shown_boxes:
      # btop lays a GPU box out as a full-width strip between the CPU box and
      # mem/net/proc, which squeezes those three down to a few lines.
      show_gpu_info = "On";
    };
  };
}
