{
  programs.direnv = {
    enable = true;
    # nix-direnv adds `use flake` — reloads shell env from flake.nix /
    # shell.nix automatically when entering a project directory.
    nix-direnv.enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;
  };
}
