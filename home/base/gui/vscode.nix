{
  config,
  lib,
  pkgs,
  ...
}:
# VS Code — Microsoft's cross-platform code editor.
#
# Packaged binary from nixpkgs (unfree — allowed by
# `nixpkgs.config.allowUnfree` in modules/base/nix.nix). Prefer a
# telemetry-free build? Swap for `vscodium`.
#
# codelldb and the C/C++ extension come from nixpkgs because the marketplace
# binaries need Nix-specific wrapping/patchelf on NixOS. `mutableExtensionsDir`
# keeps other manually installed extensions working.
let
  # Not packaged in nixpkgs yet, so build it directly from the marketplace.
  godotHoverDocs = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "godot-hover-docs";
      publisher = "RedMser";
      version = "0.1.0";
      hash = "sha256-8wBOn9P5dfQd6/24rUpIxvFnkBfQW7NBXI+jC8TxQeA=";
    };
  };

  # Remote development over SSH. Not packaged in nixpkgs, so pull it from the
  # marketplace. The publisher id is `ms-vscode-remote` (not `ms-vscode`),
  # even though Microsoft publishes it -- `ms-vscode.remote-ssh` does not exist.
  # The extension is pure JavaScript; the server it installs on the *remote*
  # host is what needs NixOS-specific handling (see `services.vscode-server`
  # or `pkgs.vscode-server` on the target machine).
  remoteSsh = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "remote-ssh";
      publisher = "ms-vscode-remote";
      version = "0.129.2026100915";
      hash = "sha256-EbCFKQ/qgPtIb2dnmAK0fcUssRB70fH5H4iLWuMyh9U=";
    };
  };

  # Lombok and Checkstyle are not packaged in nixpkgs; both are plain
  # Java/JavaScript, so the marketplace VSIX unpacks as-is.
  lombok = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "vscode-lombok";
      publisher = "vscjava";
      version = "1.1.2024071804";
      hash = "sha256-Vad2Jl0LqyzcaTq+VsLtuu55qlgNApFDYkrdSzSa94I=";
    };
  };

  checkstyle = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "vscode-checkstyle";
      publisher = "shengchen";
      version = "1.4.2";
      hash = "sha256-IchgQX9CUQ53puLu0ll8zNl6EzSnVDBj7tTUo5NzZjA=";
    };
  };

  # Redis for VS Code ships prebuilt native modules in the bundled backend
  # (`keytar`, `sqlite3`, `sshcrypto`), which link against the FHS loader and
  # libsecret; without autoPatchelf the extension fails to load on NixOS.
  # Upstream publishes only per-platform builds, hence the explicit `arch`.
  redis = pkgs.vscode-utils.buildVscodeMarketplaceExtension {
    mktplcRef = {
      name = "redis-for-vscode";
      publisher = "Redis";
      version = "1.4.0";
      arch = "linux-x64";
      hash = "sha256-SOiW8oEx1TaCqKWOaaT+Ru2SBlUzvYuE7S1wzGRo3Zs=";
    };
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      (pkgs.lib.getLib pkgs.stdenv.cc.cc)
      pkgs.libsecret
      pkgs.glib
    ];
  };
in
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;

    # The integrated terminal inherits `editor.fontFamily` when
    # `terminal.integrated.fontFamily` is unset, and both default to
    # "'Droid Sans Mono', 'monospace', monospace". Droid Sans Mono is not
    # installed here, so the terminal landed on DejaVu Sans Mono, which has no
    # Nerd Font glyphs -- every powerline separator and icon from the starship
    # prompt rendered as a .notdef box. kitty looked fine only because
    # `programs.kitty.font` names JetBrainsMono Nerd Font explicitly.
    #
    # Naming the Nerd Font family here (rather than relying on fontconfig
    # fallback) is also what upstream recommends: Chromium's fallback picks the
    # broadest-coverage font it can find, and that heuristic is unreliable on
    # Linux -- see microsoft/vscode#319988, where the terminal falls back to a
    # font that also lacks the glyph. Pinning the family skips fallback entirely.
    profiles.default.userSettings = {
      "editor.fontFamily" = "'JetBrainsMono Nerd Font', 'JetBrainsMono Nerd Font Mono', monospace";
      "terminal.integrated.fontFamily" =
        "'JetBrainsMono Nerd Font Mono', 'JetBrainsMono Nerd Font', monospace";
      # Draws box-drawing and powerline glyphs at the cell edges so the starship
      # segments join instead of leaving a seam between blocks.
      "terminal.integrated.customGlyphs" = true;

      # Previously hand-written in ~/.config/Code/User/settings.json. Now that
      # this module manages that file, they have to live here or the generated
      # symlink would drop them.
      "terminal.integrated.initialHint" = false;
      "diffEditor.ignoreTrimWhitespace" = false;
      "explorer.confirmDelete" = false;
      "git.allowForcePush" = true;

      # redhat.java shells out to a JDK. Left unset, the extension offers to
      # download one, which does not work under NixOS; point it at the JDK that
      # is already in the store instead. `mvn` / `gradle` are not implied -- add
      # them to `home.packages` if a project needs them on PATH.
      "java.jdt.ls.java.home" = "${pkgs.openjdk21.home}";

      # GitLens persists the AI model it picked on first use by writing this key
      # to the user settings file. Since that file is a read-only /nix/store
      # symlink, the write fails with EROFS and the extension retries on every
      # activation. Pinning the default here ("vscode" = the built-in Language
      # Model API, i.e. Copilot) keeps it from ever needing to write.
      "gitlens.ai.model" = "vscode";
    };

    profiles.default.extensions = [
      # Native debugging / C++.
      pkgs.vscode-extensions.vadimcn.vscode-lldb
      pkgs.vscode-extensions.ms-vscode.cpptools

      # Java. The Extension Pack only lists its members, so every one of them
      # is installed here as well -- otherwise VS Code sees the pack as
      # incomplete and fetches the missing ones from the marketplace into the
      # mutable extensions dir.
      pkgs.vscode-extensions.redhat.java
      pkgs.vscode-extensions.vscjava.vscode-java-pack
      pkgs.vscode-extensions.vscjava.vscode-java-debug
      pkgs.vscode-extensions.vscjava.vscode-java-test
      pkgs.vscode-extensions.vscjava.vscode-maven
      pkgs.vscode-extensions.vscjava.vscode-java-dependency
      pkgs.vscode-extensions.vscjava.vscode-gradle
      lombok
      checkstyle

      # Nix language support. Was installed from the marketplace until that copy
      # started shadowing the Nix one (see `removeStaleExtensions`).
      pkgs.vscode-extensions.jnoortheen.nix-ide

      # Markup.
      pkgs.vscode-extensions.redhat.vscode-xml
      pkgs.vscode-extensions.shd101wyy.markdown-preview-enhanced

      # Git history/graph. Replaces the marketplace-only Git Graph.
      pkgs.vscode-extensions.eamodio.gitlens

      # Data stores. `redis` is deliberately *not* listed here: its backend
      # writes runtime state into its own install directory, which only works if
      # that directory is writable -- see `makeRedisExtensionWritable` below.

      godotHoverDocs
      remoteSsh
    ];
  };

  # Noctalia maps the first matching category to a launcher group, and
  # Utility takes precedence over Development. Override VS Code's desktop
  # entry without Utility so it appears under Development with Godot.
  xdg.desktopEntries.code = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined.";
    exec = "code %F";
    icon = "vscode";
    categories = [
      "Development"
      "IDE"
    ];
    mimeType = [
      "application/x-code-workspace"
      "text/plain"
      "inode/directory"
    ];
    startupNotify = true;
    settings.Keywords = "vscode";
    settings.StartupWMClass = "Code";
    actions.new-empty-window = {
      name = "New Empty Window";
      exec = "code --new-window %F";
      icon = "vscode";
    };
  };

  # Redis for VS Code bundles a Redis Insight backend that keeps its runtime
  # state next to itself: `static/`, `data/`, `logs/`, `config.json`,
  # `databases.json`, `plugins/`. The extension is designed to be installed by
  # VS Code into a writable directory, so on NixOS it dies on startup with
  # `ENOENT ... mkdir .../dist/redis-backend/static/resources/plugins` -- the
  # path is inside /nix/store.
  #
  # The fix is to copy the Nix-built extension (which is the only copy that has
  # its native modules -- keytar, sqlite3, sshcrypto -- patched for NixOS) into
  # the mutable extensions dir and make it writable. `.nix-source` records which
  # store path the copy came from, so a version bump in the flake re-copies while
  # a plain rebuild leaves the accumulated backend state alone.
  #
  # It must run after `linkGeneration`, otherwise home-manager would put the
  # read-only symlink back on top of the copy.
  home.activation.makeRedisExtensionWritable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ext="${config.home.homeDirectory}/.vscode/extensions/Redis.redis-for-vscode"
    src="${redis}/share/vscode/extensions/Redis.redis-for-vscode"
    if [ -L "$ext" ] || [ ! -e "$ext" ] || [ "$(cat "$ext/.nix-source" 2>/dev/null)" != "$src" ]; then
      rm -rf "$ext"
      cp -r "$src" "$ext"
      chmod -R u+w "$ext"
      printf '%s\n' "$src" > "$ext/.nix-source"
    fi
  '';

  # VS Code installs marketplace extensions into `<id>-<version>` directories,
  # while home-manager only ever creates a version-less `<id>` symlink into the
  # store. When both exist VS Code prefers the higher version number, so a
  # marketplace copy silently shadows the Nix-declared one -- which is how the
  # Java stack ended up as JDT LS 1.56.0 (Nix) driving java-debug 0.60.0
  # (marketplace). Delete the marketplace copies so the Nix versions win, then
  # force VSCode to regenerate extensions.json from a full directory scan.
  # The home-manager immutable-extension hook only reruns when the immutable
  # list changes, so a failed first regeneration would otherwise leave the
  # Nix-managed extension invisible.
  #
  # `redis` is intentionally absent: it lives as a writable copy (see
  # `makeRedisExtensionWritable`) and has no version suffix to glob for.
  home.activation.removeStaleExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    extdir="${config.home.homeDirectory}/.vscode/extensions"
    for name in \
      eamodio.gitlens \
      jnoortheen.nix-ide \
      ms-vscode.cpptools \
      ms-vscode-remote.remote-ssh \
      redhat.java \
      redhat.vscode-xml \
      RedMser.godot-hover-docs \
      shd101wyy.markdown-preview-enhanced \
      shengchen.vscode-checkstyle \
      vadimcn.vscode-lldb \
      vscjava.vscode-gradle \
      vscjava.vscode-java-debug \
      vscjava.vscode-java-dependency \
      vscjava.vscode-java-pack \
      vscjava.vscode-java-test \
      vscjava.vscode-lombok \
      vscjava.vscode-maven; do
      rm -rf "$extdir/$name"-*
    done
    rm -f "$extdir/extensions.json" "$extdir/.init-default-profile-extensions"
  '';
}
