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
    };

    profiles.default.extensions = [
      pkgs.vscode-extensions.vadimcn.vscode-lldb
      pkgs.vscode-extensions.ms-vscode.cpptools
      pkgs.vscode-extensions.redhat.vscode-xml
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

  # Remove the marketplace copy installed from the Extensions view, then
  # force VSCode to regenerate extensions.json from a full directory scan.
  # The home-manager immutable-extension hook only reruns when the immutable
  # list changes, so a failed first regeneration would otherwise leave the
  # Nix-managed extension invisible.
  home.activation.removeStaleExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "${config.home.homeDirectory}/.vscode/extensions"/vadimcn.vscode-lldb-*
    rm -rf "${config.home.homeDirectory}/.vscode/extensions"/ms-vscode.cpptools-*
    rm -f "${config.home.homeDirectory}/.vscode/extensions"/extensions.json
    rm -f "${config.home.homeDirectory}/.vscode/extensions"/.init-default-profile-extensions
  '';
}
