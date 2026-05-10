{ modulesPath, ... }:
{
  # WARNING: the NixOS hardened profile is aggressive — it may break:
  #   - gaming (anti-cheat, GPU perf)
  #   - virtualisation (KVM/libvirt sometimes)
  #   - certain drivers and proprietary firmware
  # Enable only on machines where you understand the trade-offs.
  imports = [
    (modulesPath + "/profiles/hardened.nix")
  ];

  # Disable coredumps — they can be exploited post-crash and slow down the
  # system when something crashes. Safe to keep even without the hardened
  # profile.
  systemd.coredump.enable = false;
}
