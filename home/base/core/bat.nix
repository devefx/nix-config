{
  # `cat` clone with syntax highlighting. Also doubles as the pager for
  # `git diff` / `git log` when `core.pager = bat` is set, and works
  # well with `less -FR` for single-page exit on short outputs.
  programs.bat = {
    enable = true;
    config = {
      pager = "less -FR";
    };
  };
}
