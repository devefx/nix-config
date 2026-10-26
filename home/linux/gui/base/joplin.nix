{
  lib,
  pkgs,
  config,
  ...
}:
# Joplin — open-source note taking / to-do app with sync support (Electron),
# packaged natively in nixpkgs (v3.7.21 at the pinned nixpkgs rev).
#
# Plugins are third-party `.jpl` bundles that nixpkgs does not carry, so they
# are pinned in `pkgs/joplin-plugins/registry.nix` and symlinked into Joplin's
# plugin directory here. Joplin loads every `*.jpl` it finds in
# `<profile>/plugins` and treats a plugin with no entry in `plugins.states` as
# enabled, so a symlink is enough — no state bookkeeping needed.
#
# Managed plugins are read-only store paths: updating one goes through
# `modules.joplin.plugins` + a rebuild, not the marketplace "Update" button
# (Joplin would try to copy over the symlink and fail).
#
# Gated behind `modules.joplin.enable` — enable in `home/hosts/<name>.nix`.
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.modules.joplin;

  registry = import ../../../../pkgs/joplin-plugins/registry.nix;
  pluginPackages = import ../../../../pkgs/joplin-plugins {
    inherit pkgs;
    inherit (pkgs) lib;
  };

  # Editor Themes plugin id + the setting key it registers. Joplin namespaces
  # plugin settings as `plugin-<plugin id>.<setting key>`
  # (packages/lib/services/plugins/utils/getPluginNamespacedSettingKey.ts).
  editorThemesPlugin = "editor-themes";
  editorThemeSetting = "plugin-${registry.${editorThemesPlugin}.id}.theme";

  profileDir = "${config.home.homeDirectory}/.config/joplin-desktop";

  # Every enum value the Editor Themes plugin registers for its `theme`
  # setting (src/joplin-plugin/settings/PluginSettings.ts upstream). An
  # unknown name would be silently ignored by the plugin, so it is checked at
  # eval time instead.
  editorThemeNames = [
    "abcdef"
    "abcdef_alt"
    "abyss"
    "abyss_alt"
    "androidstudio"
    "androidstudio_alt"
    "andromeda"
    "andromeda_alt"
    "atomone"
    "aura"
    "basicDark"
    "basicDark_alt"
    "basicLight"
    "basicLight_alt"
    "bbedit"
    "bespin"
    "catppuccinMocha"
    "cobalt2"
    "consoleDark"
    "consoleLight"
    "copilot"
    "darcula"
    "dracula"
    "duotoneDark"
    "duotoneLight"
    "eclipse"
    "forest"
    "githubDark"
    "githubDark_alt"
    "githubLight"
    "githubLight_alt"
    "gruvboxDark"
    "gruvboxDark_alt"
    "gruvboxLight"
    "gruvboxLight_alt"
    "highContrastDark"
    "highContrastLight"
    "kimbie"
    "materialDark"
    "materialDark_alt"
    "materialLight"
    "materialLight_alt"
    "monokai"
    "monokai_alt"
    "monokaiDimmed"
    "noctisLilac"
    "nord"
    "nord_alt"
    "okaidia"
    "oneDark"
    "palenight"
    "quietlight"
    "red"
    "solarizedDark"
    "solarizedDark_alt"
    "solarizedLight"
    "solarizedLight_alt"
    "sublime"
    "synthwave84"
    "tokyoNight"
    "tokyoNightDay"
    "tokyoNightDay_alt"
    "tokyoNightStorm"
    "tokyoNightStorm_alt"
    "tomorrowNightBlue"
    "volcano"
    "vscodeDark"
    "vscodeDark_alt"
    "vscodeLight"
    "vscodeLight_alt"
    "whiteDark"
    "whiteLight"
    "xcodeDark"
    "xcodeLight"
  ];
in
{
  options.modules.joplin = {
    enable = mkEnableOption "Joplin note taking app";

    plugins = mkOption {
      type = types.listOf (types.enum (builtins.attrNames registry));
      default = [ ];
      example = [
        "editor-themes"
        "rich-markdown"
      ];
      description = ''
        Plugins to install, by slug from `pkgs/joplin-plugins/registry.nix`.
        Each one is symlinked into `<profile>/plugins/<plugin id>.jpl`.
      '';
    };

    editorTheme = mkOption {
      type = types.nullOr (types.enum editorThemeNames);
      default = null;
      example = "sublime";
      description = ''
        CodeMirror theme for the markdown editor, from the `editor-themes`
        plugin. Requires `"editor-themes"` in `modules.joplin.plugins`
        (asserted, not implied).

        Joplin keeps plugin settings in its SQLite database rather than in
        `settings.json`, so this is seeded into
        `~/.config/joplin-desktop/database.sqlite` on activation. The row is
        only written when absent: a theme picked in the Joplin UI afterwards is
        not overwritten by the next rebuild. Restart Joplin (or run the rebuild
        while it is closed) for a newly seeded value to take effect.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.editorTheme == null || builtins.elem editorThemesPlugin cfg.plugins;
        message = "modules.joplin.editorTheme requires \"${editorThemesPlugin}\" in modules.joplin.plugins.";
      }
    ];

    home.packages = [ pkgs.joplin-desktop ];

    home.file = lib.listToAttrs (
      map (slug: {
        name = ".config/joplin-desktop/plugins/${registry.${slug}.id}.jpl";
        value.source = "${pluginPackages.${slug}}/${registry.${slug}.id}.jpl";
      }) cfg.plugins
    );

    # Plugin settings live in Joplin's SQLite DB (`settings` table), not in
    # settings.json, so there is no file to declaratively manage. Seed the
    # editor theme once; INSERT ... WHERE NOT EXISTS keeps a later UI choice
    # authoritative.
    home.activation.joplinEditorTheme = mkIf (cfg.editorTheme != null) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        joplinDb="${profileDir}/database.sqlite"

        if [[ -f "$joplinDb" ]]; then
          ${lib.getExe pkgs.sqlite} -cmd ".timeout 5000" "$joplinDb" \
            "INSERT INTO settings (key, value)
             SELECT '${editorThemeSetting}', '${cfg.editorTheme}'
             WHERE NOT EXISTS (SELECT 1 FROM settings WHERE key = '${editorThemeSetting}');"
        else
          verboseEcho "Joplin database not found at $joplinDb; start Joplin once, then rebuild to seed the editor theme."
        fi
      ''
    );
  };
}
