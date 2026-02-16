# Nixpak sandboxed applications overlay
# Adapted from: https://github.com/ryan4yin/nix-config/tree/main/hardening/nixpaks
{
  pkgs,
  nixpak,
  ...
}:
let
  callArgs = {
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
    safeBind = sloth: realdir: mapdir: [
      (sloth.mkdir (sloth.concat' sloth.appDataDir realdir))
      (sloth.concat' sloth.homeDir mapdir)
    ];
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
in
{
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        firefox = wrapper super ./firefox.nix;
        # Add more sandboxed apps here:
        # telegram-desktop = wrapper super ./telegram-desktop.nix;
      };
    })
  ];
}
