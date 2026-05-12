{
  imports = [
    ../linux/gui.nix
  ];

  modules.aiAgents.enable = true;
  modules.wechat.enable = true;
  modules.telegram.enable = true;
}
