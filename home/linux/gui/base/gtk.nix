{ pkgs, ... }:
# GTK theme / cursor / fonts — applies to GTK apps running inside Plasma
# (e.g. Firefox, VS Code). Plasma itself uses its own (Qt) theme.
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  gtk = {
    enable = true;
    font = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 11;
    };

    # Force-rewrite ~/.gtkrc-2.0 without backup: home-manager fully owns
    # this generated file, and nixpkgs bumps change its content, which
    # otherwise collides with the stale `.home-manager.backup` copy.
    gtk2.force = true;
  };
}
