{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    nixpaks.firefox # sandboxed via nixpak (see hardening/nixpaks/)
    # Install Firefox icon (nixpak sandbox doesn't expose the original icon)
    (pkgs.runCommand "firefox-icons" {} ''
      mkdir -p $out/share
      ln -s ${pkgs.firefox}/share/icons $out/share/icons
    '')
  ];

  programs.google-chrome = {
    enable = true;
    package = if pkgs.stdenv.hostPlatform.isAarch64 then pkgs.chromium else pkgs.google-chrome;
  };
}
