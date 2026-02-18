# macOS-specific Home Manager configuration
{mylib, myvars, ...}: {
  imports =
    (mylib.scanPaths ./.)
    ++ [
      ../base/core
      ../base/home.nix
    ];

  home.homeDirectory = "/Users/${myvars.username}";

  xdg.enable = true;
}
