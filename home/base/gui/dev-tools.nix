{ pkgs, ... }:
# Cross-platform HTTP / network debugging utilities.
#
# AI coding agents live in a separate opt-in module (ai-agents.nix) so
# hosts that don't need them skip the ~GB of Node/Go/Rust runtimes.
{
  home.packages = with pkgs; [
    mitmproxy # intercepting HTTP/HTTPS proxy, script-able
    # wireshark intentionally omitted: live capture needs setuid wrapper
    # + wireshark group, which home-manager can't set up. Add via a
    # system module (`programs.wireshark.enable = true`) instead.
  ];
}
