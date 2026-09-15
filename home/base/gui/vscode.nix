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
in
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;
    profiles.default.extensions = [
      pkgs.vscode-extensions.vadimcn.vscode-lldb
      pkgs.vscode-extensions.ms-vscode.cpptools
      pkgs.vscode-extensions.redhat.vscode-xml
      godotHoverDocs
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
