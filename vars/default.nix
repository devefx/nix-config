{
  username = "yoke";
  userfullname = "Yoke Yue";
  useremail = "yoke.yue@outlook.com";

  # GitHub namespace used by git's url.insteadOf rewrites.
  githubUsername = "devefx";

  # NixOS / home-manager state version — must stay pinned at install-time
  # release even after upgrading, otherwise stateful modules (postgres,
  # ~/.config schemas) silently migrate.
  stateVersion = "25.11";

  # Generated via: mkpasswd -m yescrypt --rounds=11
  initialHashedPassword = "$y$jFT$JUngg/W4gWCUrycUmqVb.1$7u6saIKJbKaLCy34709U7ZeOJrFV8is.Wgm2MeLmMh6";

  # SSH public keys trusted on this config's machines.
  mainSshAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtGB+2LpNX/QbowSrJJyIFavclLFDjIp/xszX70k/Jd yoke@macbook"
  ];

  # Backup keys for disaster recovery (main key lost / device broken).
  secondaryAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvu2hW0bwbHAcE6WzcNr2OyqSymNvwwPzZtSyBSraCO yoke@backup"
  ];
}
