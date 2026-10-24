{ pkgs, ... }:
let
  # Catppuccin's yazi port, pinned by commit rather than vendored as a Nix
  # attrset: 746 of its 882 lines are the per-extension/per-filename icon table,
  # which would be unreadable transcribed by hand and impossible to diff against
  # upstream. `fetchurl` keeps the file byte-identical to what the port ships.
  #
  # Pinned to a commit rather than `main`: the theme file is upstream state, and
  # a moving branch would change the build hash without a diff here.
  #
  # The `mauve` accent variant, out of the port's one-file-per-accent set. The
  # accent only drives the mode label, the selected marker and dialog borders
  # (39 occurrences); mauve is the same value the Catppuccin kitty port uses for
  # its active tab, so the two agree.
  theme = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/yazi/d62802be39210ea10e54b3e3b09735c6cb9e57c1/themes/macchiato/catppuccin-macchiato-mauve.toml";
    hash = "sha256-U2wqK7RgCM0D9ecjgmGB8K5yXt9wizCJEfnKhLDU3bk=";
  };

  # The `.tmTheme` that `theme` references via `syntect_theme`, for syntax
  # highlighting in the preview pane. yazi's port does not ship one; it points
  # at catppuccin/bat's copy.
  syntect = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/catppuccin/bat/6810349b28055dce54076712fc05fc68da4b8ec0/themes/Catppuccin%20Macchiato.tmTheme";
    hash = "sha256-EQCQ9lW5cOVp2C+zeAwWF2m1m6I0wpDQA5wejEm7WgY=";
  };
in
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

  # `programs.yazi.theme` is deliberately not used: it would mean transcribing
  # the 882-line file into a Nix attrset, and home-manager's TOML generator
  # would then reorder its keys anyway. Linking the file in as-is keeps it
  # identical to what the port ships.
  #
  # The `syntect_theme` value inside that file is `~/.config/yazi/Catppuccin-
  # macchiato.tmTheme`, and yazi expands `~` before its "must be absolute"
  # check, so the .tmTheme only has to land at the same path -- the upstream
  # file needs no rewriting.
  xdg.configFile = {
    "yazi/theme.toml".source = theme;
    "yazi/Catppuccin-macchiato.tmTheme".source = syntect;
  };
}
