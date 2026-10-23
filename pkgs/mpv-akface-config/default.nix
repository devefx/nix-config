{
  lib,
  stdenv,
  fetchurl,
  unzip,
  writeText,
}:

let
  # Pinned to the upstream release. Bump `version` and every `hash` in `skins`
  # together when moving to a new release.
  version = "1.9.27";

  # The upstream release publishes one zip per (skin, language) pair. Only the
  # skins listed here are pinned, which keeps `nix flake check` honest: an
  # unknown skin is a build-time error rather than a silent fallback.
  skins = {
    modernz = {
      # ModernZ -- the classic OSC look, thumbnails via thumbfast.
      file = "modernz_zh.zip";
      hash = "sha256-MTQd0oLP0CWsA0C2mlQTwTX+Fd7Ob2nmZuPY9BR1QvE=";
    };
    modern_glass = {
      # ModernGlass -- floating glass panels, Inter font, thumbnails via the
      # newer thumbz renderer.
      file = "modern_glass_zh.zip";
      hash = "sha256-OiPG2S+lnm/fzcNzIozL7CaeRdL1FEI1PQKFgNDZ+xc=";
    };
    uosc = {
      # uosc -- the config used to drive this repo before the akFace tree.
      file = "uosc_zh.zip";
      hash = "sha256-iqIK6ZD8f0dobaLAVRw7SyGToZVclaG3eSHXunGtqao=";
    };
  };

  # Local options layered on top of the upstream mpv.conf. The upstream file
  # ships an `include=~~/custom-opts.conf` line commented out; we re-enable it
  # in installPhase so these survive future config bumps untouched.
  customOpts = writeText "mpv-custom-opts.conf" ''
    # Managed by nix-config. The upstream akFace/mpv.config tree is copied
    # verbatim and must not be edited by hand -- put local tweaks here instead.
    #
    # Note: upstream mpv.conf ends inside its `[macos-arm]` profile block, so
    # appending to that file would land in the wrong profile. This include sits
    # in the global section at the top, which is why it is used instead.

    # Niri tiles mpv across the full width/height and letterboxes the video
    # inside that tile (see home/linux/gui/niri/conf/windowrules.kdl). Stop mpv
    # from resizing its own window to the video aspect ratio and fighting the
    # compositor over the geometry.
    auto-window-resize=no
    keepaspect=yes
    keepaspect-window=no
    panscan=0.0
    wayland-configure-bounds=yes
  '';
in
{
  # `skin` is passed by home/linux/gui/base/mpv.nix. Each skin gets its own
  # derivation name so switching skins is a distinct store path -- the
  # activation script keys its "config changed" stamp off this path.
  mkConfig =
    skin:
    let
      selected =
        skins.${skin}
          or (throw "mpv-akface-config: unknown skin '${skin}', expected one of ${toString (lib.attrNames skins)}");
    in
    stdenv.mkDerivation (finalAttrs: {
      pname = "mpv-akface-config-${skin}";
      inherit version;

      src = fetchurl {
        url = "https://github.com/akFace/mpv.config/releases/download/v${finalAttrs.version}/${selected.file}";
        inherit (selected) hash;
      };

      nativeBuildInputs = [ unzip ];

      # The release zip has no single top-level directory, so unpack it
      # directly into $out rather than letting stdenv guess a source root.
      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out"
        unzip -q "$src" -d "$out"

        # Re-enable the `include` line. The whole line is replaced because
        # mpv.conf has no inline comments -- leaving the trailing explanation
        # behind would turn it into part of the include path.
        sed -i \
          's|^# include = "~~/custom-opts.conf".*$|include = "~~/custom-opts.conf"|' \
          "$out/mpv.conf"

        cp ${customOpts} "$out/custom-opts.conf"

        # Full-size window instead of upstream's autofit=60%. Patched in place
        # because mpv processes `include` (line 18) before this line (line 68),
        # so custom-opts.conf cannot win.
        sed -i 's|^autofit=.*|autofit=100%|' "$out/mpv.conf"

        # Windows-only leftovers from the cross-platform release archive.
        rm -f "$out/mpvnet.conf"

        # Manifest of every file this skin ships. The activation script uses it
        # to delete files left behind by a previously selected skin -- e.g.
        # modernz ships thumbfast.lua while modern_glass ships thumbz.lua, and
        # both grab overlay id 42, so a stale copy breaks the seekbar previews.
        # `find` output is sorted for a stable derivation hash.
        ( cd "$out" && find . -type f | LC_ALL=C sort ) > "$out/.manifest"

        runHook postInstall
      '';

      meta = {
        description = "akFace/mpv.config drop-in mpv configuration (${skin} skin, zh-CN)";
        homepage = "https://github.com/akFace/mpv.config";
        license = lib.licenses.lgpl21Only;
        platforms = lib.platforms.all;
      };
    });
}
