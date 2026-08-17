{
  imports = [
    ../linux/gui.nix
  ];

  modules.aiAgents.enable = true;
  modules.ccSwitch.enable = true;
  modules.godot.enable = true;
  modules.llamaCpp.enable = true;
  modules.comfyui.enable = true;
  modules.obs.enable = true;
  modules.wasThumbnail.enable = true;
  modules.wechat.enable = true;
  modules.karere.enable = true;
  modules.telegram.enable = true;
  modules.qq.enable = true;
  modules.ime.enable = true;
  modules.feishin.enable = true;
  modules.tsukimi.enable = true;
  modules.eden.enable = true;
  modules.remmina.enable = true;
}
