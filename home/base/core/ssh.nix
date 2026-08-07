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