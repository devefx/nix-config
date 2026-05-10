{
  # Terminal file manager — blazing fast, vim-like keys, image preview
  # via kitty's graphics protocol.
  #
  # Usage: `yazi` opens it. Better: use `yy` (the wrapper below) — on
  # exit it cd's your shell to whatever directory you navigated to
  # inside yazi. Kills the classic "navigate → copy path → cd" loop.
  programs.yazi = {
    enable = true;
    shellWrapperName = "yy";

    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    settings = {
      mgr = {
        show_hidden = true; # dotfiles visible by default
        sort_dir_first = true; # directories always on top
      };
    };
  };
}
