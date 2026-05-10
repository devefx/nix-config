{
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    historyLimit = 100000;
    keyMode = "vi";
    mouse = true;
    # C-a is easier to reach than the default C-b.
    prefix = "C-a";
    baseIndex = 1;
    escapeTime = 10;
  };
}
