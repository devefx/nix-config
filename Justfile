# Justfile — common operations
# Usage: just <recipe>
# Requires: https://github.com/casey/just

# Default recipe: show help
default:
    @just --list

# ── NixOS ─────────────────────────────────────────────────────

# Build and switch NixOS configuration
[linux]
switch hostname="nixos-desktop":
    sudo nixos-rebuild switch --flake .#{{hostname}}

# Build NixOS configuration without switching
[linux]
build hostname="nixos-desktop":
    nixos-rebuild build --flake .#{{hostname}}

# Test NixOS configuration (switch but don't add to boot menu)
[linux]
test hostname="nixos-desktop":
    sudo nixos-rebuild test --flake .#{{hostname}}

# ── macOS (nix-darwin) ────────────────────────────────────────

# Build and switch Darwin configuration
[macos]
switch hostname="darwin-laptop":
    darwin-rebuild switch --flake .#{{hostname}}

# Build Darwin configuration without switching
[macos]
build hostname="darwin-laptop":
    darwin-rebuild build --flake .#{{hostname}}

# ── Common ────────────────────────────────────────────────────

# Update all flake inputs
update:
    nix flake update

# Update a specific input
update-input input:
    nix flake update {{input}}

# Check flake for errors
check:
    nix flake check

# Format all nix files
fmt:
    nix fmt

# Show flake outputs
show:
    nix flake show

# Garbage collect old generations
gc:
    sudo nix-collect-garbage -d

# List system generations (NixOS)
[linux]
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
