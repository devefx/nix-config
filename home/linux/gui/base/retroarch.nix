{
  lib,
  pkgs,
  config,
  ...
}:
# RetroArch — the reference frontend for the libretro API (multi-system
# emulator: NES / SNES / GB / GBA / MD / PS1 / N64 / DS / arcade ...).
#
# Gated behind `modules.retroarch.enable` — enable in
# `home/hosts/<name>.nix`.
#
# `pkgs.retroarch` ships **no** cores: in nixpkgs it is
# `retroarch-bare.wrapper { }` with an empty core list (see
# pkgs/top-level/all-packages.nix), so the wrapper only provides the binary.
# Cores are plain libretro libraries and have to be chosen explicitly, hence
# the `cores` option below. Each selected core is symlinked into the wrapper
# and gets a matching `-L <core>` default flag, so it appears in RetroArch's
# "Load Core" menu without any per-core path setup.
#
# A few things that do *not* need configuring here:
#   - Workspace and tile size: the niri window rule in
#     home/linux/gui/niri/conf/windowrules.kdl opens it on 4entertainment at a
#     full-workspace column height and width.
#   - Assets (menu icons), joypad autoconfig profiles and the core info list
#     are already wired in by retroarch-bare's default config
#     (retroarch-assets / retroarch-joypad-autoconfig / libretro-core-info),
#     and the default input driver reads /dev/input/event* — access comes from
#     the `input` group in modules/nixos/base/user-group.nix.
#   - The runtime config (video/audio driver, shaders, playlists, saves) is
#     created on first launch at ~/.config/retroarch/retroarch.cfg. It is
#     deliberately mutable rather than declarative: RetroArch rewrites that
#     file from its own menus, and saves/states live next to it.
#
# The UI font *does* need configuring — see `uiFont` for the tofu-box bug —
# and on a HiDPI desktop so does the menu scale — see `menuScaleFactor`.
#
# Under niri (no X11 compositor of its own) RetroArch starts on xwayland-
# satellite with the `gl` driver. If frames land on the wrong output or
# vsync misbehaves, set `video_driver = "vulkan"` plus
# `video_vulkan_display_enable = "true"` in the GUI — the package is built
# with Vulkan + Wayland support (withVulkan / withWayland default to true).
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.modules.retroarch;

  # `pkgs.libretro` also exposes helpers (callPackage, newScope, ...), so
  # only entries that actually build a libretro core are valid names.
  availableCores = lib.filterAttrs (_: core: core ? libretroCore) pkgs.libretro;

  selectedCores = map (name: lib.getAttr name availableCores) cfg.cores;

  # RetroArch's FreeType renderer deliberately refuses to open some font files
  # — gfx/drivers_font_renderer/freetype.c:
  #
  #     if (!*font_path || strstr(font_path, "fallback"))
  #
  #     That branch means "ask fontconfig for a Sans font matching the UI
  #     language" instead of loading the file. Ozone relies on it for CJK: on a
  #     Chinese UI it passes assets/pkg/chinese-fallback-font.ttf, and the
  #     Korean/Arabic cases pass *-fallback-font.ttf too.
  #
  # That lookup is only as good as the host's fontconfig. Here
  # `fc-match 'Sans:lang=zh'` answers DejaVu Sans — a Latin-only font — so
  # every Chinese menu label rendered as a tofu box (□), while the bundled
  # font on disk covers U+4E00-U+9FA5 just fine. Measured with strace: with a
  # Chinese UI RetroArch never opened chinese-fallback-font.ttf at all, it only
  # opened DejaVuSans.ttf through fontconfig.
  #
  # Copy that same bundled font to a store path whose name does not contain
  # "fallback" so the direct-load branch runs (`FT_New_Memory_Face` on the real
  # file). Verified: 10 opens of this path during startup, no fontconfig match.
  # Keeping upstream's font also keeps the intended Chinese glyph shapes and
  # needs no extra dependency.
  uiFont = pkgs.runCommand "retroarch-ui-font.ttf" { } ''
    install -Dm644 ${pkgs.retroarch-assets}/share/retroarch/assets/pkg/chinese-fallback-font.ttf $out
  '';

  # RetroArch has no idea about the compositor's scale factor. It computes its
  # own menu scale in gfx/gfx_display.c:
  #
  #     dpi_scale   = dpi / 96
  #     pixel_scale = diagonal_pixels / DIAGONAL_PIXELS_1080P
  #     scale       = dpi_scale            # 12" < diagonal/dpi < 24"
  #
  # and the DPI itself comes straight from the output's *physical size*:
  # gfx/common/wayland_common.c does `oi->width * 25.4 / oi->physical_width`
  # (x11_common.c the same with DisplayWidth/DisplayWidthMM).
  #
  # This monitor reports a 290 mm wide panel for a 3840 px wide mode, i.e.
  # 336 dpi, so RetroArch picks a 3.5x menu scale *on top of* the 2x the
  # compositor already applies to the buffer — the UI ends up ~1.75x larger
  # than every other window. `menu_scale_factor` is the only knob that can
  # undo that (it multiplies the computed scale, see
  # gfx_display_get_dpi_scale); the correct value depends on the monitor and
  # on the desktop scale, hence the option instead of a hardcoded number.

  retroarch = pkgs.wrapRetroArch {
    cores = selectedCores;
    # `--appendconfig`, i.e. read-only at runtime: picking another Menu Font in
    # the GUI will not survive a restart. That is intended — the GUI default is
    # exactly the broken path above.
    settings = {
      ozone_font = cfg.uiFont;
      xmb_font = cfg.uiFont; # same bug, should the menu driver ever be xmb
      video_font_path = cfg.uiFont; # OSD toasts (e.g. "配置已保存至 ...")
      # wrapRetroArch interpolates settings values straight into the
      # `--appendconfig` file, so floats have to be pre-formatted.
      menu_scale_factor = toString cfg.menuScaleFactor;
    };
  };
in
{
  options.modules.retroarch = {
    enable = mkEnableOption "RetroArch libretro frontend";

    menuScaleFactor = mkOption {
      type = types.float;
      default = 1.0;
      description = ''
        Multiplier applied on top of RetroArch's own DPI-derived menu scale
        (`menu_scale_factor`).

        RetroArch does not read the compositor's scale; it guesses a scale from
        the display's DPI, and that guess is only as good as the monitor's EDID
        (see the comment above `uiFont` in this module). Use this to divide the
        bad guess back down to the size the rest of the desktop uses, e.g.
        `2.0 / 3.5` for a 2x-scale output that RetroArch thinks is 3.5x.
      '';
    };

    uiFont = mkOption {
      type = types.path;
      default = uiFont;
      description = ''
        Font file used for the menu (Ozone and XMB) and the on-screen display.

        Must point at a file whose path does not contain `fallback` (RetroArch
        hands such paths to fontconfig instead of loading them, see the comment
        above `uiFont` in this module) and must contain CJK glyphs, otherwise
        Chinese text renders as tofu boxes. The default is RetroArch's own
        `chinese-fallback-font.ttf` (Droid Sans Fallback), copied to a
        non-`fallback` name.
      '';
    };

    cores = mkOption {
      type = types.listOf types.str;
      default = [
        # Nintendo
        "fceumm" # NES
        "snes9x" # SNES
        "gambatte" # GB / GBC
        "mgba" # GBA
        "mupen64plus" # N64
        "melonds" # DS
        # Sega
        "genesis-plus-gx" # Genesis / Mega Drive / Game Gear
        # Sony — beetle-psx needs a PS1 BIOS dumped to the system dir
        "beetle-psx" # PS1
        # Arcade
        "fbneo" # Capcom / Neo Geo / arcade boards
      ];
      example = [
        "snes9x"
        "dolphin" # GameCube / Wii
      ];
      description = ''
        libretro cores to install, by their `pkgs.libretro` attribute name.
        The full list is whatever nixpkgs ships under `pkgs.libretro`; a
        standalone emulator (eden, dolphin, ...) is generally a better choice
        for disc-based systems, these are the light cartridge-era ones.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (name: availableCores ? ${name}) cfg.cores;
        message = ''
          modules.retroarch.cores: unknown libretro core(s) ${
            lib.concatStringsSep ", " (lib.filter (name: !(availableCores ? ${name})) cfg.cores)
          }.
          Valid names are the attributes of `pkgs.libretro` that provide a
          `libretroCore`, e.g. snes9x, mgba, gambatte, genesis-plus-gx,
          beetle-psx, mupen64plus, melonds, fbneo, dolphin.
        '';
      }
    ];

    home.packages = [ retroarch ];
  };
}
