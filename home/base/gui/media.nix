{ pkgs, ... }:
# Cross-platform media-processing CLI tools. Everything here is
# command-line — the file lives in `gui/` (not `tui/` or `core/`) because
# the outputs are typically viewed / consumed via GUI (images, videos,
# rendered graphs).
{
  home.packages = with pkgs; [
    # -------- Audio / video processing --------
    ffmpeg-full # swiss army knife: transcode, trim, extract audio,
    # generate thumbnails, screen record, etc.

    # -------- Images --------
    viu # terminal image viewer — native kitty + iTerm2 graphics protocol
    imagemagick # `convert` / `mogrify` / `identify` for batch image processing

    # -------- Graphs --------
    graphviz # `dot` — render DOT language → PNG/SVG (architecture diagrams,
    # pprof flame graphs, AST visualization, etc.)
  ];
}
