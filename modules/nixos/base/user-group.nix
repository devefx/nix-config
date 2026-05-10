{ myvars, ... }:
{
  users.mutableUsers = false;

  users.users."${myvars.username}" = {
    isNormalUser = true;
    description = myvars.userfullname;
    home = "/home/${myvars.username}";
    extraGroups = [
      "wheel"
      "networkmanager"
      # Desktop groups — harmless on headless hosts.
      "audio"
      "video"
      "input"
    ];
    initialHashedPassword = myvars.initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
  };
}
