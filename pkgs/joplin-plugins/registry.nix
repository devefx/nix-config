# Joplin plugins, pinned by version + hash.
#
# The bundles are the exact `.jpl` files the marketplace serves behind
# https://joplinapp.org/plugins/plugin/<id> ("download this plugin's .jpl
# file"), i.e. the `plugins` tag of the joplin/plugins releases bucket.
# Nixpkgs does not package third-party plugins, so they are fetched here and
# installed by `home/linux/gui/base/joplin.nix`.
#
# To bump one: open the plugin's marketplace page, take the new version and
# `nix store prefetch-file --json --name <id>-<version>.jpl <url>` for the hash.
# The slug (left-hand key) is what `modules.joplin.plugins` takes.
{
  # 70+ CodeMirror themes, including Sublime. `modules.joplin.editorTheme`
  # writes its `theme` setting.
  editor-themes = {
    id = "com.ckant.joplin-plugin-editor-themes";
    version = "1.1.0";
    hash = "sha256-VMYM2ypEpyBn+Ai78rEJsHNM21NKpdO2syUYJhTk66U=";
  };

  # Inline images, clickable checkboxes and extra CSS classes in the markdown
  # editor, so the viewer pane is no longer needed.
  rich-markdown = {
    id = "plugin.calebjohn.rich-markdown";
    version = "0.17.3";
    hash = "sha256-4OAIYox4pD0YAZWz0L3PNStBYSs7yOBXbySqJou6PcQ=";
  };

  # Side-by-side diff of the note against its previous revision.
  diff-view = {
    id = "io.github.personalizedrefrigerator.diff-view";
    version = "0.3.1";
    hash = "sha256-pkz2GZ0W9/vAFjs62RZ0IDzvXwkORf34PYk632VXozY=";
  };

  # Re-aligns the markdown table around the cursor.
  table-formatter = {
    id = "net.rmusin.joplin-table-formatter";
    version = "1.2.1";
    hash = "sha256-oDnv2YkuZWBd+Tn6f1Qnhx5pBO0lRSgL+H5AIxu1RB4=";
  };

  # Generated `<!-- note-overview-plugin -->` blocks that list notes matching a
  # search query (recent notes, open todos, per-tag indexes).
  note-overview = {
    id = "io.github.jackgruber.note-overview";
    version = "1.7.1";
    hash = "sha256-C5OeaM0JgJe3YNd8ILpcgwrD7D0G8MR+GbtLoAOmkYs=";
  };

  # Fenced-code-block language autocomplete plus a matching insert command.
  codeblock-autocomplete = {
    id = "com.bwat47.codeblock-autocomplete";
    version = "1.6.0";
    hash = "sha256-cBkVd1K9iLpvzxWs7eGpcKpJEIrfNYLu0+fBXXZdPBs=";
  };
}
