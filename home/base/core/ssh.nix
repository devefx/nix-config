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

      # The nginx LXC on the Proxmox host (192.168.16.254) -- not PVE itself.
      # The key deliberately lives in ~/.ssh, not on the NAS share: /mnt/ssh is
      # CIFS with `x-systemd.idle-timeout=300`, so a VSCode Remote-SSH reconnect
      # after five idle minutes has to wait for the automount before it can read
      # the key, and any hiccup on the NAS turns into a failed handshake.
      nginx = {
        HostName = "192.168.16.246";
        User = "root";
        IdentityFile = "~/.ssh/pve_nginx";
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
