# Just recipes for this flake.
# Usage: `just <recipe>`; `just` lists recipes.

default:
    @just --list

# Build and switch to a host config (default: current hostname).
switch host=`hostname`:
    sudo nixos-rebuild switch --flake ".#{{host}}"

# Dry-build a host config without switching.
build host=`hostname`:
    nixos-rebuild build --flake ".#{{host}}"

# Update all flake inputs.
update:
    nix flake update

# Format all nix files.
fmt:
    nix fmt

# Run eval-tests and pre-commit checks.
check:
    nix flake check
