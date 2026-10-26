{
  lib,
  pkgs,
}:
# One derivation per pinned plugin in ./registry.nix, keyed by slug, each
# producing `$out/<plugin-id>.jpl`.
#
# Not an overlay on purpose: nothing else in the config needs to see these,
# and `home/linux/gui/base/joplin.nix` is the only consumer.
let
  registry = import ./registry.nix;
in
lib.mapAttrs (_slug: plugin: pkgs.callPackage ./plugin.nix plugin) registry
