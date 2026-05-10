{ pkgs, ... }:
# Sandboxed Firefox — runs inside bubblewrap via nixpak. The sandbox
# config is in hardening/nixpaks/firefox.nix; it grants Firefox access
# only to:
#   - ~/.mozilla (profile)
#   - ~/Documents / ~/Downloads / ~/Music / ~/Videos / ~/Pictures
#   - /etc/gnupg + ~/.gnupg + ~/.local/share/password-store
#     (for the browserpass / GPG workflow)
#   - GPU / wayland / pipewire sockets
# Notably DENIED: ssh keys, dotfiles, source code, everything else.
#
# Trade-off: `programs.firefox`'s declarative profile settings (about:config
# tweaks, extensions, search engines) are NOT used here — the wrapped
# package doesn't plug into that option. Configure Firefox once via its
# UI after first launch; settings persist in ~/.mozilla and survive
# rebuilds / redeployments.
#
# Recommended first-launch tweaks in Firefox UI:
#   - Settings → Privacy & Security → Strict tracking protection
#   - Settings → Home → Firefox Home Content → uncheck "Sponsored ..."
#   - Settings → General → Startup → "Open previous windows and tabs"
{
  home.packages = with pkgs; [
    nixpaks.firefox
  ];
}
