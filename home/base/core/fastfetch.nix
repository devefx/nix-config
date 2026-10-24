let
  # fastfetch's config is JSONC, and Nix string literals have no `\u` escape --
  # writing "\u001b" would reach the terminal as those six characters. The ESC
  # byte is decoded from JSON once here and interpolated instead.
  esc = builtins.fromJSON "\"\\u001b\"";

  # The Catppuccin cat, byte-for-byte from pfetch's `Catppuccin` ASCII art
  # (unseen-ninja/pfetch, the fork that added it), with two uniform spaces added
  # in front of every line.
  #
  # The uniform prefix shifts the whole drawing right without deforming it --
  # the leading spaces *inside* the art (line 1 and line 3) shape the head and
  # the ear and are untouched. Each line gets the same amount, so the silhouette
  # is identical, just indented.
  #
  # Why indent at all: the art is 11 cells wide at its widest, and fastfetch
  # left-aligns the logo block, so without the prefix the cat sits flush against
  # the left edge and looks crowded. `padding.left` would do the same thing, but
  # it also pushes the info column right; adding the spaces here and taking the
  # same amount off `padding.right` below keeps the info column where it is.
  #
  # Each line is prefixed with ANSI colour 2, which is what pfetch uses for this
  # art (`read_ascii 2`). kitty maps colour 2 to Macchiato's green #A6DA95
  # through the active theme, so no hex value is hardcoded here -- change the
  # kitty theme and the cat follows.
  #
  # The trailing U+200E LRM characters on the last line are part of the original
  # art, not noise -- they keep the glyph from being reordered in RTL contexts.
  cat = [
    "   /| ､"
    "  (°､ ｡ 7"
    "   |､  ~ヽ"
    "   じしf_,)〳‎‎"
  ];
  catLogo = builtins.concatStringsSep "\n" (map (line: "${esc}[32m${line}") cat);
in
{
  # System info panel — the neofetch-style logo-plus-facts display, laid out
  # like pfetch's rather than fastfetch's own presets: no border, no box-drawing
  # characters, no colour swatch. Just the cat on the left and a plain
  # `key  value` column on the right.
  #
  # Configured through home-manager's `programs.fastfetch`, which writes
  # $XDG_CONFIG_HOME/fastfetch/config.jsonc. Schema:
  # https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json
  #
  # Printed from bash.nix's initExtra rather than wired in here.
  programs.fastfetch = {
    enable = true;

    settings = {
      logo = {
        # `data-raw` because the art carries its own escape sequences. The
        # `data` variant would try to interpret them as fastfetch colour
        # placeholders, and `logo.color` only applies to built-in logos -- a
        # `data` source ignores it entirely (verified).
        type = "data-raw";
        source = catLogo;
        # pfetch pads the art column to 13 cells. The cat above is 11 cells at
        # its widest plus the 2-cell prefix, so `right = 1` puts the info column
        # at cell 14 -- unchanged from before the prefix was added.
        #
        # `top = 2` vertically centres the art against the module column. The
        # module list is 7 lines and the art 4, so the slack is 3 -- an odd
        # number, which cannot be split evenly; 2 above and 1 below reads as
        # centred, whereas 1/2 sits visibly high. fastfetch has no "centre the
        # logo" option: padding is the only vertical control, and trailing
        # newlines in `source` are stripped, so this offset has to be tuned by
        # hand whenever a module is added or removed.
        padding = {
          top = 2;
          left = 0;
          right = 1;
        };
      };

      display = {
        # Two spaces between the (padded) art and the info column, and between
        # key and value. pfetch uses no separator glyph at all.
        separator = "  ";

        # pfetch prints lowercase names left-aligned with no separator, values
        # starting at a fixed column. `width = 8` fits the longest key
        # (`uptime`) and gives the same look.
        key = {
          type = "string";
          width = 8;
          color = "green";
        };
      };

      modules = [
        # pfetch's `title` line: user@host, no key. The colours mirror pfetch's
        # default `PF_COL3` (title in colour 1) and green `@`.
        {
          type = "title";
          key = " ";
          format = "${esc}[33m{user-name}${esc}[32m@${esc}[33m{host-name}";
        }
        {
          type = "os";
          key = "os";
          format = "{pretty-name} {codename}";
        }
        {
          type = "host";
          key = "host";
        }
        {
          type = "kernel";
          key = "kernel";
        }
        {
          type = "uptime";
          key = "uptime";
        }
        {
          type = "packages";
          key = "pkgs";
          # `{all}` sums nix-system + nix-user into one number, which is what
          # pfetch's `pkgs` line reports. The default fastfetch format would
          # print both counts separately.
          format = "{all}";
        }
        {
          type = "memory";
          key = "memory";
          format = "{used} / {total}";
        }
      ];
    };
  };
}
