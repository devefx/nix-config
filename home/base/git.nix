# Git configuration (cross-platform)
{myvars, ...}: {
  programs.git = {
    enable = true;

    settings = {
      user.name = myvars.userfullname;
      user.email = myvars.useremail;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
    };
  };
}
