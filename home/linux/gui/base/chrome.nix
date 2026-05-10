{
  # Google Chrome — closed-source, tied to Google account.
  #
  # NOT sandboxed via nixpak — Chrome has its own strong multi-process
  # namespace sandbox built into every renderer / GPU / network process.
  # Wrapping it in bubblewrap would conflict with that mechanism.
  #
  # Requires `nixpkgs.config.allowUnfree = true;` (set at system level
  # in modules/base/nix.nix) because Chrome ships as non-free software.
  #
  # Trade-offs vs Chromium:
  #   + Widevine DRM (Netflix HD, Spotify, some paid streams)
  #   + Google account sync (bookmarks, passwords, extensions)
  #   - closed source, Google telemetry, auto-update unfriendly to Nix
  programs.google-chrome = {
    enable = true;
  };
}
