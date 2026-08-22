{
  imports = [
    ../linux/gui.nix
  ];

  modules.cpp.enable = true;
  modules.rust.enable = true;
  modules.aiAgents.enable = true;
  modules.ccSwitch.enable = true;
  modules.godot.enable = true;
  modules.godotDev.enable = true;
  modules.godotAndroid.enable = true;
  modules.godotWindows.enable = true;
  modules.godotWeb.enable = true;
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
  modules.emby.enable = true;
}
