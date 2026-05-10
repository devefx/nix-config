# lib

**English** | [简体中文](./README.zh-CN.md)

Factory functions and utility helpers.

## Contents

| File | Purpose |
|------|---------|
| `default.nix` | Entry point — exposes everything as `mylib.*` via specialArgs |
| `nixosSystem.nix` | Factory that wraps `nixpkgs.lib.nixosSystem` with home-manager wiring |
| `attrs.nix` | Attrset helper placeholder — add list/attr utilities as you grow |

## Key exports (reachable as `mylib.<name>` in any module)

| Export | Purpose |
|--------|---------|
| `mylib.nixosSystem` | Factory — host files call it with `{ nixos-modules, home-modules, ... }` |
| `mylib.scanPaths path` | Returns every `<path>/*.nix` and subdir (except `default.nix`) — used by module `default.nix` files |
| `mylib.relativeToRoot` | Turns a string like `"modules/nixos"` into an absolute module path |
| `mylib.attrs` | Attrset helpers |

## Why factories

Host files only assemble a list of `nixos-modules` + `home-modules` and
hand them to `mylib.nixosSystem`. All the nixpkgs / home-manager wiring
lives in one place so hosts stay a handful of lines.

When you add a new platform (darwin, riscv, etc.) or a new deployment
mode (colmena, nixos-generators image), add a new factory here rather
than duplicating the nixosSystem wiring in every host file.

## Adding utilities

Drop a new `<name>.nix` that exports helper functions, then add it to
`default.nix` so it's reachable as `mylib.<name>` everywhere.
