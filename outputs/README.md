# outputs

**English** | [简体中文](./README.zh-CN.md)

Flake output aggregation layer. `flake.nix` delegates here via
`outputs = import ./outputs`.

## Structure

```
outputs/
├── default.nix              top-level: injects specialArgs, aggregates across architectures
└── x86_64-linux/
    ├── default.nix          haumea-loads ./src, merges nixosConfigurations / packages
    └── src/
        ├── faex1.nix        one file = one host
        └── pve-lab1.nix
```

## How it works

1. `default.nix` builds `genSpecialArgs` — the bag of extras injected
   into every NixOS / home-manager module: `mylib`, `myvars`,
   `pkgs-stable`, plus every flake input.
2. For each supported system (currently just `x86_64-linux`) it delegates
   to `outputs/<system>/default.nix`.
3. The per-system `default.nix` uses **haumea** to auto-load every
   `.nix` in `./src/`. Each file returns a small attrset with
   `nixosConfigurations.<name>` (and optionally `packages.<name>`).
   Haumea merges them.
4. Back at the top level, per-system results get merged into the final
   flake outputs (`nixosConfigurations`, `packages`, `checks`,
   `devShells`, `formatter`).

## Adding a host

Drop a file at `outputs/x86_64-linux/src/<host>.nix`. Template:

```nix
{ inputs, lib, myvars, mylib, system, genSpecialArgs, ... }@args:
let
  name = "<host>";
  modules = {
    nixos-modules = map mylib.relativeToRoot [
      "modules/nixos"
      "hosts/${name}"
      # ...add sandbox, desktop, server modules as needed
    ];
    home-modules = map mylib.relativeToRoot [
      "home/hosts/${name}.nix"
    ];
  };
in {
  nixosConfigurations."${name}" = mylib.nixosSystem (modules // args);
}
```

Haumea picks the file up automatically — no manifest to edit.

## Adding a platform

Add an `outputs/<arch>/` directory with its own `default.nix` + `src/`,
then register it in `outputs/default.nix`'s `nixosSystems` /
`darwinSystems` map.
