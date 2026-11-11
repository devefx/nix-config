{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "spotify-adblock";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "abba23";
    repo = "spotify-adblock";
    tag = "v1.1.1";
    hash = "sha256-R1xM/a+EzFd3I94EVCphbW+M114x6CtIeCOi9Fd9tpc=";
  };

  cargoHash = "sha256-gxGetdqaoJa/ZF1VnW6UXJyJfLBGZxZnyKpT/Qk/8Og=";

  # Upstream ships a cdylib, not a binary: the Makefile installs
  # libspotifyadblock.so plus the denylist config that the library reads from
  # /etc/spotify-adblock/config.toml (or $XDG_CONFIG_HOME/spotify-adblock/).
  installPhase = ''
    runHook preInstall

    # buildRustPackage passes --target, so the cdylib lands under
    # target/<triple>/release rather than target/release.
    install -Dm755 "$(find target -name libspotifyadblock.so -print -quit)" \
      $out/lib/spotify-adblock.so
    install -Dm644 config.toml $out/etc/spotify-adblock/config.toml

    runHook postInstall
  '';

  meta = {
    description = "Adblocker for the Spotify desktop client (LD_PRELOAD)";
    homepage = "https://github.com/abba23/spotify-adblock";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
