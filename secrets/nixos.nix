{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
# Age-encrypted secrets via agenix — asymmetric encryption with age keys.
#
# Plaintext secrets never live in this repo. Encrypted `.age` files are
# committed to the private `mysecrets` repo
# (https://github.com/devefx/nix-secrets), pulled via git+ssh as a flake
# input, and decrypted at activation using the host's SSH host key
# (`/etc/ssh/ssh_host_ed25519_key`).
#
# To add / rotate a secret on a host:
#   1. ssh-to-age -i /etc/ssh/ssh_host_ed25519_key   # host age public key
#   2. agenix -e <name>.age -r <age-pubkey>          # encrypt; commit to nix-secrets
#   3. declare it below as age.secrets.<name>
let
  inherit (lib) mkEnableOption mkIf mkMerge;
  cfg = config.modules.secrets;
in
{
  imports = [ agenix.nixosModules.default ];

  options.modules.secrets = {
    enable = mkEnableOption "age-encrypted secrets (agenix)";
    smb.enable = mkEnableOption "SMB share credentials secret";
    hf.enable = mkEnableOption "Hugging Face token secret";
    piWeb.enable = mkEnableOption "Pi Web environment file secret (password + PI_WEB_* overrides)";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Decrypt with the machine's SSH host key — never leaves the box.
    age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    age.secrets = mkMerge [
      (mkIf cfg.smb.enable {
        # TrueNAS (192.168.16.251)
        smb-credentials = {
          file = "${mysecrets}/smb-credentials.age";
          owner = myvars.username;
          group = "users";
          mode = "0600";
        };
        # Windows Server (192.168.16.206) — wd_20t share
        smb-credentials-wd20t = {
          file = "${mysecrets}/smb-credentials-wd20t.age";
          owner = myvars.username;
          group = "users";
          mode = "0600";
        };
      })
      (mkIf cfg.hf.enable {
        hf-token = {
          file = "${mysecrets}/hf-token.age";
          owner = myvars.username;
          group = "users";
          mode = "0600";
        };
      })
      (mkIf cfg.piWeb.enable {
        # Read by Pi Web's systemd *user* service as an EnvironmentFile, so the
        # owner has to be the user, not root: the user manager reads the file
        # after agenix has decrypted it as root. Contents are
        # `PI_WEB_PASSWORD=...` lines, nothing else.
        pi-web = {
          file = "${mysecrets}/pi-web.age";
          owner = myvars.username;
          group = "users";
          mode = "0400";
        };
      })
    ];
  };
}
