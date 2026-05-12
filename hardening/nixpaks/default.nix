{
  pkgs,
  nixpak,
  ayugram-desktop,
  ...
}:
let
  # Shared args for every nixpak-wrapped app.
  callArgs = {
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
    # Bind a real directory under XDG_DATA_HOME into the sandbox's $HOME,
    # so the app only sees its own data dir and nothing else of yours.
    safeBind = sloth: realdir: mapdir: [
      (sloth.mkdir (sloth.concat' sloth.appDataDir realdir))
      (sloth.concat' sloth.homeDir mapdir)
    ];
    # Pre-resolve flake-input packages so individual .nix files don't
    # have to know about flake plumbing.
    ayugramDesktop = ayugram-desktop.packages.${pkgs.system}.ayugram-desktop;
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
in
{
  # Register nixpak-wrapped apps under `pkgs.nixpaks.<name>`.
  # To add a new sandboxed app:
  #   1. create `./<app>.nix` next to this file
  #   2. add `<app> = wrapper super ./<app>.nix;` to the overlay below
  #   3. reference it as `pkgs.nixpaks.<app>` in home-manager / nixos modules
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        firefox = wrapper super ./firefox.nix;
        telegram-desktop = wrapper super ./telegram-desktop.nix;
        ayugram-desktop = wrapper super ./ayugram-desktop.nix;
      };
    })
  ];
}
