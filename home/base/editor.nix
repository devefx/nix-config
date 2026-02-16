# Editor configuration (cross-platform)
{pkgs, ...}: {
  # Neovim as default editor
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Set EDITOR environment variable
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
