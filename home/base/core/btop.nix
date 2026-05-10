{
  # btop — fancy htop replacement. Generates ~/.config/btop/btop.conf.
  programs.btop = {
    enable = true;
    settings = {
      # Use terminal's background instead of btop's dark bg —
      # lets transparent terminals show through.
      theme_background = false;
    };
  };
}
