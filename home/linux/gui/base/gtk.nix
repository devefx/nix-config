{ pkgs, ... }:
# GTK theme / cursor / fonts — applies to GTK apps running inside Plasma
# (e.g. Firefox, VS Code). Plasma itself uses its own (Qt) theme.
{
  home.pointerCursor = {
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
  };
}
