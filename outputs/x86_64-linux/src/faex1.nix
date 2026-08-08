{
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "faex1";
  modules = {
    nixos-modules =
      map mylib.relativeToRoot [
        "modules/nixos"
        # Desktop module group — provides `modules.desktop.*` toggles.
        "modules/nixos/desktop"
        "hosts/${name}"
        # Age-encrypted secrets (agenix) — see secrets/nixos.nix.
        "secrets/nixos.nix"
        # Sandbox overlays — safe to always import, they only register
        # `pkgs.nixpaks.*` / `pkgs.bwraps.*` namespaces. Zero effect until
        # you actually reference one.
        "hardening/nixpaks"
        "hardening/bwraps"
        # Full system hardening — uncomment if you want NixOS's hardened
        # profile. Read hardening/profiles/default.nix first, it breaks things.
        # "hardening/profiles"
      ]
      ++ [ inputs.grub2-themes.nixosModules.default ];
    home-modules = map mylib.relativeToRoot [
      "home/hosts/${name}.nix"
    ];
  };
in
{
  nixosConfigurations = {
    "${name}" = mylib.nixosSystem (modules // args);
  };
}
