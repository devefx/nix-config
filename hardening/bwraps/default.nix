{
  # Register raw-bubblewrap-wrapped apps under `pkgs.bwraps.<name>`.
  # Useful for AppImage-style binaries where `nixpak`'s DSL is overkill
  # and you want to hand-tune `extraBwrapArgs`.
  #
  # To add a new sandboxed app:
  #   1. create `./<app>.nix` next to this file
  #   2. add `<app> = super.callPackage ./<app>.nix { };` below
  #   3. reference it as `pkgs.bwraps.<app>`
  nixpkgs.overlays = [
    (_: super: {
      bwraps = {
        wechat = super.callPackage ./wechat.nix { };
      };
    })
  ];
}
