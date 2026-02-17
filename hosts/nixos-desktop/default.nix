# NixOS desktop host configuration
{
  inputs,
  myvars,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Boot loader ──────────────────────────────────────────────
  # GRUB with EFI + Windows dual-boot
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      extraEntries = ''
        menuentry "Windows" {
          search --file --no-floppy --set=root /EFI/Microsoft/Boot/bootmgfw.efi
          chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  networking.hostName = "yoke-nixos";

  # Allow IP forwarding (needed for clash TUN mode)
  networking.firewall.checkReversePath = false;
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
  };

  # User account
  users.users.${myvars.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "audio"];
    openssh.authorizedKeys.keys = myvars.sshAuthorizedKeys;
  };

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "25.11";
}
