{
  imports = [
    ../linux/gui.nix
  ];

  modules.aiAgents.enable = true;
  modules.ccSwitch.enable = true;
  modules.wechat.enable = true;
  modules.telegram.enable = true;
  modules.ime.enable = true;
  modules.feishin.enable = true;
}
