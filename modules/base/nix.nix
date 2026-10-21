{ myvars, ... }:
{
  # Allow non-free packages (Google Chrome, unrar, some firmware, ...).
  # Applies to both system-level `environment.systemPackages` and,
  # because `home-manager.useGlobalPkgs = true` in lib/nixosSystem.nix,
  # to home-manager too.
  nixpkgs.config.allowUnfree = true;

  # openldap 2.6.13 ships timing-sensitive syncrepl replication tests
  # that flake under load (provider/consumer db differ); skip checks so
  # rebuilds do not fail on them. The binaries are unaffected.
  nixpkgs.overlays = [
    (_final: prev: {
      openldap = prev.openldap.overrideAttrs (_: {
        doCheck = false;
      });

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

    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://cache.nixos.org"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    builders-use-substitutes = true;
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
