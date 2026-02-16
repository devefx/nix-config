# Git configuration (cross-platform)
{myvars, ...}: {
  programs.git = {
    enable = true;
    userName = myvars.userfullname;
    userEmail = myvars.useremail;

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
    };

    delta = {
      enable = true; # Better git diff
      options = {
        navigate = true;
        side-by-side = true;
      };
    };
  };
}
