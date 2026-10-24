{
  config,
  lib,
  pkgs,
  ...
}:
# Bash as the interactive shell.
#
# home-manager only owns ~/.bashrc when `programs.bash.enable` is set. Without
# it the `enableBashIntegration` flags in starship.nix / direnv.nix / eza.nix
# have nowhere to write their init snippets, which is why the prompt stayed
# plain despite those modules being enabled.
#
# Note this takes over ~/.bashrc: home-manager renames the existing file to
# ~/.bashrc.home-manager.backup on first activation. Anything that has to stay
# belongs in `initExtra` below.
{
  programs.bash = {
    enable = true;

    # `interactiveShellInit` is sourced for interactive non-login shells
    # (every terminal window). `initExtra` is appended after the generated
    # content, so it can rely on starship already being initialised.
    initExtra = ''
      # System info panel on terminal start, but only in a terminal wide enough
      # to fit the bordered layout without wrapping -- the value column alone
      # is 60 cells, plus the logo, so anything narrower wraps the right border.
      #
      # `tput cols` rather than $COLUMNS: COLUMNS is not exported to .bashrc at
      # this point, so it would read as empty and the test would always fail.
      #
      # Guarded on $KITTY_WINDOW_ID so ssh sessions and tmux panes stay quiet,
      # and on $FASTFETCH_SHOWN so nested shells do not re-print it.
      if [[ -n ''${KITTY_WINDOW_ID:-} ]] && [[ -z ''${FASTFETCH_SHOWN:-} ]]; then
        if (( $(tput cols 2>/dev/null || echo 0) >= 100 )); then
          fastfetch
          export FASTFETCH_SHOWN=1
        fi
      fi
    '';
  };

  # Keep the PATH tweak that used to live in the hand-written ~/.bashrc.
  # home-manager backs that file up rather than merging it, so the line has to
  # be reproduced here or ~/.local/bin drops off PATH.
  home.sessionPath = [ "$HOME/.local/bin" ];
}
