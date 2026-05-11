{ myvars, ... }:
{
  home = {
    inherit (myvars) username stateVersion;
    homeDirectory = "/home/${myvars.username}";
  };

  programs.home-manager.enable = true;
}
