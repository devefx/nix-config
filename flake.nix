{
  description = "My Nix configuration";

  outputs = inputs: import ./outputs inputs;

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      # gufo's own cache: the patched ROCr, the ROCm 10.1 / LLVM 24 stack it
      # links against and the gfx1151 builds are all absent from
      # cache.nixos.org, so without this every gufo bump compiles LLVM+ROCm
      # from source (hours). Same keys the upstream flake declares.
      "https://gufo.cachix.org"
      # noctalia's cache, built against the nixpkgs pinned in its own flake.
      # It only hits while the noctalia input keeps its own nixpkgs (see below);
      # adding `inputs.nixpkgs.follows` would force a local C++ build.
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-26.05";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The 26.04 release still has the long-DPMS connector reconnect failure.
    niri = {
      url = "github:niri-wm/niri";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    godot-yoke = {
      url = "github:MHGameDevs/godot/yoke";
      flake = false;
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # GRUB theme — provides `boot.loader.grub2-theme` NixOS module.
    grub2-themes = {
      url = "github:vinceliuice/grub2-themes";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # directory -> attrset auto-loader
    haumea = {
      url = "github:nix-community/haumea/v0.2.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix code formatter + typo + prettier checks
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # declarative bubblewrap sandboxing for per-app isolation
    nixpak = {
      url = "github:nixpak/nixpak";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # AI coding agents — packages Claude Code / Codex / Gemini CLI / etc.
    # Does NOT follow our nixpkgs (agents pin their own supported versions).
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Gufo — inference engine specialised for Strix Halo (gfx1151). Follows our
    # nixpkgs for everything but ROCm: it carries its own nixpkgs-rocm10 pin
    # (ROCm 10.1 / LLVM 24) because the ROCm in nixpkgs (7.2.x) has no gfx1151
    # kernels. That closure comes from gufo.cachix.org, see nixConfig above.
    gufo = {
      url = "github:gufo-org/gufo/v0.26.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia v5 - the C++/Wayland rewrite of the desktop shell. It is a
    # different program from the v4 `noctalia-shell` (Quickshell) package, so it
    # is a separate input rather than a nixpkgs version bump: nixpkgs unstable
    # still carries an older release, while the config here uses keys added in
    # 5.3/5.4.
    #
    # 5.5.0 over 5.4.1: it carries upstream's tray InputArea reuse (commit
    # 7756d21aa and PR #5184, fixing issue #4537). On 5.4.1 a tray app that
    # animates its icon (WeChat, Telegram, MEGA, an active Discord call, ...)
    # rebuilds the whole tray widget on every update, which destroys the drawer
    # button's InputArea: its hover flickers and clicks are dropped while the
    # icon animates.
    #
    # Deliberately NOT following our nixpkgs: upstream publishes prebuilt
    # binaries on cachix built against their own nixpkgs pin, and following ours
    # would change the derivation hash and force a local C++ build.
    noctalia.url = "github:noctalia-dev/noctalia/v5.5.0";

    # age-encrypted secrets — asymmetric (age keys). Encrypted `.age` files
    # live in the private nix-secrets repo; decrypted at activation using the
    # host's SSH key.
    agenix = {
      url = "github:ryantm/agenix/4835b1dc898959d8547a871ef484930675cb47f1";
      inputs.nixpkgs.follows = "nixpkgs";
      # agenix pins its own (2025-04) home-manager. Nothing we use depends on
      # it — `homeManagerModules.age` is a bare path, and the input only feeds
      # agenix's own darwin `checks` — so following ours is purely about
      # keeping one home-manager node in flake.lock instead of two.
      inputs.home-manager.follows = "home-manager";
    };

    # Personal desktop wallpapers, mounted by the Niri session.
    wallpapers = {
      url = "github:devefx/wallpapers";
      flake = false;
    };

    # Private secrets repo (git+ssh, must exist & be reachable from hosts):
    # https://github.com/devefx/nix-secrets
    mysecrets = {
      url = "git+ssh://git@github.com/devefx/nix-secrets.git?shallow=1";
      flake = false;
    };
  };
}
