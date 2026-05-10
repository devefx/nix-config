{ mylib, ... }:
# Desktop module group. Import this explicitly from hosts that need a GUI.
# Individual features gated behind `modules.desktop.<name>.enable`.
{
  imports = mylib.scanPaths ./.;
}
