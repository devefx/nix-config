# Linux-specific shell configuration
{
  config,
  myvars,
  ...
}: let
  d = config.xdg.dataHome;
  c = config.xdg.configHome;
  cache = config.xdg.cacheHome;
in {
  home.homeDirectory = "/home/${myvars.username}";

  home.sessionVariables = {
    # clean up ~
    LESSHISTFILE = cache + "/less/history";
    LESSKEY = c + "/less/lesskey";
    WINEPREFIX = d + "/wine";

    # set default applications
    BROWSER = "firefox";

    # enable scrolling in git diff
    DELTA_PAGER = "less -R";
  };
}
