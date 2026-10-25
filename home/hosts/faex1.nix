{
  imports = [
    ../linux/gui.nix
  ];

  modules.cpp.enable = true;
  modules.rust.enable = true;
  modules.aiAgents.enable = true;
  # Pi Web binds 0.0.0.0:30141. There is no `PI_WEB_PASSWORD` set, so only
  # enable this on a network you trust (see the module for how to add one).
  modules.aiAgents.piWeb.enable = true;
  # REA registers as an MCP server for Pi / Pi Web / Codex / DSH and ships its
  # skill. `ghidra` also installs Ghidra + JDK 21 for the decompiler-backed
  # tools.
  modules.aiAgents.rea = {
    enable = true;
    ghidra = true;
  };
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
  modules.mpv.enable = true;
  modules.eden.enable = true;
  modules.remmina.enable = true;
  modules.emby.enable = true;
  modules.hongguoTv.enable = true;
  modules.vicinae.enable = true;
  modules.moonlight.enable = true;
}
