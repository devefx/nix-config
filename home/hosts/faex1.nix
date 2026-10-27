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
  modules.joplin = {
    enable = true;
    plugins = [
      "editor-themes"
      "rich-markdown"
      "diff-view"
      "table-formatter"
      "note-overview"
      "codeblock-autocomplete"
    ];
    editorTheme = "sublime";
  };
  modules.feishin.enable = true;
  modules.tsukimi.enable = true;
  modules.mpv.enable = true;
  modules.eden.enable = true;
  # RetroArch scales its UI from the monitor's reported DPI (EDID here says
  # 290 mm for a 3840 px wide panel → 336 dpi → 3.5x) while niri already
  # scales the buffer by 2, so the menu would come out ~1.75x oversized.
  # Divide the bad 3.5x guess back down to the compositor's 2x.
  modules.retroarch = {
    enable = true;
    menuScaleFactor = 2.0 / 3.5;
  };
  modules.remmina.enable = true;
  modules.hongguoTv.enable = true;
  modules.vicinae.enable = true;
  modules.thunderbird = {
    enable = true;
    autostart = true;
  };
  modules.moonlight.enable = true;
}
