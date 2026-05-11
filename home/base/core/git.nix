{
  config,
  lib,
  myvars,
  ...
}:
{
  # `programs.git` generates ~/.config/git/config — but git prefers
  # ~/.gitconfig if it exists, silently ignoring our config. Nuke it.
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f ${config.home.homeDirectory}/.gitconfig
  '';

  # GitHub CLI — `gh pr create`, `gh auth login`, etc.
  programs.gh.enable = true;

  programs.git = {
    enable = true;
    lfs.enable = true;

    # Uncomment and fill when you have a signing key set up.
    # signing = {
    #   format = "openpgp";
    #   signByDefault = true;
    #   key = "<GPG key ID or path to ssh key>";
    # };

    # `settings` mirrors ~/.config/git/config 1:1 — `user`, `init`,
    # `alias`, etc. match the section names you see in the raw gitconfig.
    settings = {
      user.name = myvars.userfullname;
      user.email = myvars.useremail;

      init.defaultBranch = "main";
      # Auto-track remote on first `git push` of a new branch.
      push.autoSetupRemote = true;
      # `git pull` rebases instead of merging (cleaner history).
      pull.rebase = true;
      # Human-readable timestamps in `git log`.
      log.date = "iso";

      # Rewrite https → ssh for own GitHub namespace, so
      # `git clone https://github.com/<user>/xxx` silently uses the ssh
      # remote (uses ssh-agent, respects your ed25519 key).
      url = {
        "ssh://git@github.com/${myvars.githubUsername}" = {
          insteadOf = "https://github.com/${myvars.githubUsername}";
        };
      };

      alias = {
        br = "branch";
        co = "checkout";
        st = "status";
        cm = "commit -m"; # git cm "message"
        ca = "commit -am"; # add + commit
        dc = "diff --cached";
        amend = "commit --amend -m";
        unstage = "reset HEAD --";
        merged = "branch --merged"; # list branches merged into HEAD
        unmerged = "branch --no-merged";
        nonexist = "remote prune origin --dry-run";
      };
    };
  };

  # Syntax-highlighted pager for git diff / log / blame.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      diff-so-fancy = true;
      line-numbers = true;
      true-color = "always";
    };
  };

  # Git TUI — interactive staging, commit, log browsing, rebase.
  programs.lazygit.enable = true;

  # Yet another Git TUI (written in rust).
  programs.gitui.enable = false;
}
