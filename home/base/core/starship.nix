{
  # The upstream Catppuccin Powerline preset, taken verbatim from
  # https://starship.rs/presets/catppuccin-powerline
  # (zh-CN page: https://starship.rs/zh-CN/presets/catppuccin-powerline)
  #
  # Kept as a copy rather than shelling out to `starship preset ... -o` at
  # activation time: the preset is a plain TOML document, and copying it in
  # makes the whole prompt reviewable in the diff instead of appearing in
  # ~/.config as an untracked runtime artifact.
  #
  # Deliberate differences from upstream:
  #
  #   1. `palettes` carries the four Catppuccin flavours and not the extra
  #      ayu_* palettes the upstream TOML bundles next to them; the Catppuccin
  #      values are byte-for-byte upstream's.
  #   2. `jj_bookmark` / `jj_status` are omitted entirely -- see the comment in
  #      place of them below.
  #   3. `os.symbols.NixOS` is set to the monochrome `linux-nixos` glyph -- see
  #      the comment on it below.
  #
  # Everything else -- segment order, backgrounds, symbols, the `crust`
  # foreground on every coloured block, `line_break.disabled` -- is upstream's,
  # including the blocks for tools this machine does not have (`bun`, `php`,
  # `java`, `kotlin`, `haskell`, `conda`, `docker_context`). Those are inert
  # until the tool shows up on PATH, and keeping them makes this file diffable
  # against the preset. `docker_context` is kept even though the preset's
  # `format` never renders `$docker_context`.
  #
  # Prerequisites from the preset docs: a Nerd Font in the terminal. kitty is
  # configured with nerd-fonts.jetbrains-mono, so the powerline glyphs
  # (U+E0B0 / U+E0B2 / U+E0B4 / U+E0B6) and the icons resolve.
  programs.starship = {
    enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = true;

    settings = {
      "$schema" = "https://starship.rs/config-schema.json";

      # Upstream writes this as a TOML multi-line string with trailing `\`
      # line continuations, which TOML collapses into one line with no
      # separators. Writing the collapsed form directly matters here: the
      # home-manager TOML generator would otherwise emit a literal `\` plus
      # a newline into the format, and starship would print both.
      format = "[](red)$os$username[](bg:peach fg:red)$directory[](bg:yellow fg:peach)$git_branch$git_status[](fg:yellow bg:green)$c$rust$golang$nodejs$bun$php$java$kotlin$haskell$python[](fg:green bg:sapphire)$conda[](fg:sapphire bg:lavender)$time[ ](fg:lavender)$cmd_duration$line_break$character";

      # Upstream default is Mocha; this config uses Macchiato. Switch back to
      # `catppuccin_mocha`, or to `catppuccin_frappe` / `catppuccin_latte`, for
      # the other flavours -- every palette is already defined below.
      palette = "catppuccin_macchiato";

      os = {
        disabled = false;
        style = "bg:red fg:crust";
        symbols = {
          Windows = " ";
          Ubuntu = "󰕈 ";
          SUSE = " ";
          Raspbian = "󰐿 ";
          Mint = "󰣭 ";
          Macos = "󰀵 ";
          Manjaro = " ";
          Linux = "󰌽 ";
          Gentoo = "󰣨 ";
          Fedora = "󰣛 ";
          Alpine = " ";
          Amazon = " ";
          Android = " ";
          AOSC = " ";
          Arch = "󰣇 ";
          Artix = "󰣇 ";
          CachyOS = " ";
          CentOS = " ";
          Debian = "󰣚 ";
          Redhat = "󱄛 ";
          RedHatEnterprise = "󱄛 ";
          Void = " ";
          # Not in the preset. starship's built-in fallback for NixOS is the
          # `❄️ ` emoji, and an emoji ignores the segment's `fg:crust` -- it is
          # drawn in its own colours, i.e. near-white on the `red` (#ed8796)
          # block, which is barely legible. U+F313 (`linux-nixos`) is a
          # monochrome Nerd Font glyph instead, so it inherits `fg:crust`
          # (#181926) and matches the `$user` text next to it.
          NixOS = " ";
        };
      };

      username = {
        show_always = true;
        style_user = "bg:red fg:crust";
        style_root = "bg:red fg:crust";
        format = "[$user]($style)";
      };

      directory = {
        style = "bg:peach fg:crust";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
        substitutions = {
          "Documents" = "󰈙 ";
          "Downloads" = " ";
          "Music" = "󰝚 ";
          "Pictures" = " ";
          "Developer" = "󰲋 ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:yellow";
        format = "[[ $symbol $branch ](fg:crust bg:yellow)]($style)";
      };

      git_status = {
        style = "bg:yellow";
        format = "[[($all_status$ahead_behind )](fg:crust bg:yellow)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      bun = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      c = {
        symbol = " ";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      php = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      java = {
        symbol = " ";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      # Escaping note for the `python` format: upstream writes it as a TOML
      # literal string, so `\(` in the TOML source reaches starship as one
      # backslash. Nix has no `\(` escape at all -- a backslash before `(` is
      # passed through as-is -- so one literal backslash is written `\\`.
      #
      # `jj_bookmark` / `jj_status` are absent because starship 1.26 (what
      # nixpkgs ships) predates the jujutsu modules: any `[jj_bookmark]` table
      # makes it print
      #
      #   WARN (starship::config): Error in 'StarshipRoot' at 'jj_bookmark': Unknown key
      #
      # on the first prompt of every shell. `disabled = true` does not help --
      # the warning comes from deserialisation, before the flag is consulted
      # (verified: a table containing nothing but `disabled = true` still
      # warns). The preset's `format` never renders these segments, so nothing
      # is lost; restore both blocks once starship knows the keys.
      kotlin = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      haskell = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version) ](fg:crust bg:green)]($style)";
      };

      python = {
        symbol = "";
        style = "bg:green";
        format = "[[ $symbol( $version)(\\(#$virtualenv\\)) ](fg:crust bg:green)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:sapphire";
        format = "[[ $symbol( $context) ](fg:crust bg:sapphire)]($style)";
      };

      conda = {
        symbol = "  ";
        style = "fg:crust bg:sapphire";
        format = "[$symbol$environment ]($style)";
        ignore_base = false;
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:lavender";
        format = "[[  $time ](fg:crust bg:lavender)]($style)";
      };

      line_break.disabled = true;

      character = {
        disabled = false;
        success_symbol = "[❯](bold fg:green)";
        error_symbol = "[❯](bold fg:red)";
        vimcmd_symbol = "[❮](bold fg:green)";
        vimcmd_replace_one_symbol = "[❮](bold fg:lavender)";
        vimcmd_replace_symbol = "[❮](bold fg:lavender)";
        vimcmd_visual_symbol = "[❮](bold fg:yellow)";
      };

      cmd_duration = {
        show_milliseconds = true;
        format = " in $duration ";
        style = "bg:lavender";
        disabled = false;
        show_notifications = true;
        min_time_to_notify = 45000;
      };

      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
      };

      palettes.catppuccin_frappe = {
        rosewater = "#f2d5cf";
        flamingo = "#eebebe";
        pink = "#f4b8e4";
        mauve = "#ca9ee6";
        red = "#e78284";
        maroon = "#ea999c";
        peach = "#ef9f76";
        yellow = "#e5c890";
        green = "#a6d189";
        teal = "#81c8be";
        sky = "#99d1db";
        sapphire = "#85c1dc";
        blue = "#8caaee";
        lavender = "#babbf1";
        text = "#c6d0f5";
        subtext1 = "#b5bfe2";
        subtext0 = "#a5adce";
        overlay2 = "#949cbb";
        overlay1 = "#838ba7";
        overlay0 = "#737994";
        surface2 = "#626880";
        surface1 = "#51576d";
        surface0 = "#414559";
        base = "#303446";
        mantle = "#292c3c";
        crust = "#232634";
      };

      palettes.catppuccin_latte = {
        rosewater = "#dc8a78";
        flamingo = "#dd7878";
        pink = "#ea76cb";
        mauve = "#8839ef";
        red = "#d20f39";
        maroon = "#e64553";
        peach = "#fe640b";
        yellow = "#df8e1d";
        green = "#40a02b";
        teal = "#179299";
        sky = "#04a5e5";
        sapphire = "#209fb5";
        blue = "#1e66f5";
        lavender = "#7287fd";
        text = "#4c4f69";
        subtext1 = "#5c5f77";
        subtext0 = "#6c6f85";
        overlay2 = "#7c7f93";
        overlay1 = "#8c8fa1";
        overlay0 = "#9ca0b0";
        surface2 = "#acb0be";
        surface1 = "#bcc0cc";
        surface0 = "#ccd0da";
        base = "#eff1f5";
        mantle = "#e6e9ef";
        crust = "#dce0e8";
      };

      palettes.catppuccin_macchiato = {
        rosewater = "#f4dbd6";
        flamingo = "#f0c6c6";
        pink = "#f5bde6";
        mauve = "#c6a0f6";
        red = "#ed8796";
        maroon = "#ee99a0";
        peach = "#f5a97f";
        yellow = "#eed49f";
        green = "#a6da95";
        teal = "#8bd5ca";
        sky = "#91d7e3";
        sapphire = "#7dc4e4";
        blue = "#8aadf4";
        lavender = "#b7bdf8";
        text = "#cad3f5";
        subtext1 = "#b8c0e0";
        subtext0 = "#a5adcb";
        overlay2 = "#939ab7";
        overlay1 = "#8087a2";
        overlay0 = "#6e738d";
        surface2 = "#5b6078";
        surface1 = "#494d64";
        surface0 = "#363a4f";
        base = "#24273a";
        mantle = "#1e2030";
        crust = "#181926";
      };
    };
  };
}
