{
  # Modern `ls` replacement. `programs.eza` auto-adds ls/ll/la aliases
  # in bash/zsh (no effect in nushell — it has its own ls builtin).
  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    # nushell's builtin `ls` already outputs structured tables —
    # aliasing to eza there would be worse.
    enableNushellIntegration = false;
    git = true;
    icons = "auto";
  };
}
