{ mylib, ... }:
# DE-agnostic Linux GUI bits — applies regardless of which compositor /
# desktop environment is enabled. GTK theme is the canonical example
# (GTK apps run on KDE, Hyprland, GNOME, ... alike).
{
  imports = mylib.scanPaths ./.;
}
