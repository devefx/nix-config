{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    # `matchBlocks` is deprecated — `settings` uses upstream ssh_config
    # directive names; each key becomes a `Host <key>` block.
    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = true;
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };

      # Proxmox VE host. The key lives on the NAS share mounted at /mnt/ssh,
      # which is why that mount is restricted to file_mode=0600.
      nginx = {
        HostName = "192.168.16.246";
        User = "root";
        IdentityFile = "/mnt/ssh/pve_nginx";
      };

      # Port 22 is blocked on many networks; use SSH-over-HTTPS.
      "github.com" = {
        HostName = "ssh.github.com";
        Port = 443;
        User = "git";
        IdentitiesOnly = true;
      };
    };
  };
}
