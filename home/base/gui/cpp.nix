{
  lib,
  pkgs,
  config,
  ...
}:
# C/C++ toolchain for VS Code (C/C++ + clangd extensions).
#
# The extensions themselves are installed from the VS Code Extensions
# view (~/.vscode, survive rebuilds); this module provides the tooling
# they drive:
#   - gcc / gdb     — compiler + debugger (C/C++ extension defaults)
#   - cmake/ninja   — CMake + Ninja build system
#   - clang-tools   — clangd (LSP), clang-format, clang-tidy
#
# Gated behind `modules.cpp.enable` — only hosts that develop C/C++
# pull the toolchain. Enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.modules.cpp;
in
{
  options.modules.cpp = {
    enable = mkEnableOption "C/C++ toolchain (gcc, gdb, cmake, clangd)";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      gcc # C/C++ compiler
      gdb # debugger
      cmake # build system
      ninja # fast CMake backend
      clang-tools # clangd LSP + clang-format + clang-tidy
    ];
  };
}
