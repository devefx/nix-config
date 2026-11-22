{ myvars, ... }:
{
  # Allow non-free packages (Google Chrome, unrar, some firmware, ...).
  # Applies to both system-level `environment.systemPackages` and,
  # because `home-manager.useGlobalPkgs = true` in lib/nixosSystem.nix,
  # to home-manager too.
  nixpkgs.config.allowUnfree = true;

  # home-manager's fcitx5 module always builds a GTK 2 immodule cache
  # (`gtk2-immodule.cache`, modules/i18n/input-method/default.nix), putting
  # `pkgs.gtk2` in the closure. The 2026-11 nixpkgs bump marked GTK 2 broken
  # (removal planned for 27.05) and evaluation now aborts instead of warning;
  # nothing here uses GTK 2 directly, so keep it evaluable. Drop this once
  # home-manager stops pulling GTK 2 in.
  nixpkgs.config.problems.handlers."gtk+".broken = "warn";

  # openldap 2.6.13's syncrepl replication tests are timing-sensitive and flake
  # under load. It used to be overridden with `doCheck = false`, but that
  # changes its hash and rebuilds openldap plus its consumers locally (gnupg,
  # gcr, apache-httpd, nfs-utils, the lutris FHS rootfs) on every nixpkgs bump.
  # cache.nixos.org already carries it with the tests passing, so the override
  # cost more than it saved. If a future nixpkgs rev forces a local build and
  # the tests flake, add this back temporarily:
  #
  #   openldap = prev.openldap.overrideAttrs (_: { doCheck = false; });
  nixpkgs.overlays = [
    (_final: prev: {
      # gtk3 3.24.52 leaks the zxdg_output_v1 proxy that GDK creates per monitor:
      # gdk_wayland_monitor_finalize() destroys the wl_output but not the proxy,
      # so the proxy's listener keeps pointing at the freed monitor. A later
      # xdg_output.name event then does `g_free (monitor->name)` on freed memory.
      #
      #   #0  <client>
      #   #1  g_free (libglib-2.0.so.0)
      #   #2  xdg_output_handle_name (libgdk-3.so.0)
      #
      # Any output hotplug can hit this. A compositor that repeatedly re-adds and
      # removes a connector makes it reliable: every GTK3 client gets the removal
      # plus a fresh name event each cycle, and they all die together. Upstream
      # fixed it in 692439ec8d41 ("Don't leak zxdg_output_v1 proxy") after
      # 3.24.52, and GTK4 already destroyed the proxy; see the patch for the full
      # analysis.
      #
      # This is a package bug, not a desktop-feature one, so it is applied for
      # every host rather than behind a `modules.desktop.*` toggle. It rebuilds
      # gtk3 and therefore every GTK3 consumer (chrome, electron, vscode, ...).
      gtk3 = prev.gtk3.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../patches/gtk3-monitor-xdg-output-destroy.patch ];
      });
    })
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-users = [ myvars.username ];

    # Measured from this host (8 MiB ranged nar download, 2026-11):
    #   cache.nixos.org        5.08 MB/s, TTFB 0.42 s
    #   mirrors.ustc.edu.cn    3.01 MB/s, TTFB 0.92 s
    #   mirror.nju.edu.cn      2.24 MB/s, TTFB 0.53 s
    #   mirror.sjtu.edu.cn     0.16 MB/s, TTFB 6.52 s  ← unusable, dropped
    #
    # SJTU used to be the fastest mirror and was listed first; it now stalls at
    # ~0.16 MB/s (a 20 GiB rebuild went from ~70 min to ~36 h), and Nix does not
    # try the next substituter until the current one fails — a slow first entry
    # is worse than no entry at all. Direct cache.nixos.org wins, keep the two
    # CN mirrors for the days the direct route is degraded.
    substituters = [
      "https://cache.nixos.org"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://mirror.nju.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      # gufo (modules/nixos/server/gufo.nix) links against a patched ROCr and
      # ROCm 10.1 / LLVM 24 that cache.nixos.org does not carry. Upstream
      # publishes them here; without it a gufo bump rebuilds LLVM+ROCm.
      "https://gufo.cachix.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "gufo.cachix.org-1:rfZe3n4lHINgyoACKzs5EthIZmBNvEyCCtufUpth0PE="
    ];

    builders-use-substitutes = true;
    auto-optimise-store = true;

    # Fail over fast instead of hanging on a stalled mirror, and widen the
    # download fan-out (default is 25) so a 20 GiB substitution saturates the
    # link with many small narinfo/nar requests rather than one at a time.
    connect-timeout = 10;
    stalled-download-timeout = 30;
    download-attempts = 3;
    http-connections = 32;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
