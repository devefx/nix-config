{myvars, ...}: {
  home = {
    inherit (myvars) username;
    stateVersion = "24.11";
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
