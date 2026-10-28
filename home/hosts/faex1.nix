{
  osConfig,
  ...
}:
{
  imports = [
    ../linux/gui.nix
  ];

  modules.cpp.enable = true;
  modules.rust.enable = true;
  modules.aiAgents = {
    enable = true;

    # Pi Web binds 0.0.0.0:30141, so it is behind the agenix-managed password
    # below: the secret is an EnvironmentFile holding `PI_WEB_PASSWORD=...`, and
    # `environmentFile` hands that path to the unit. The file is decrypted at
    # activation with the host key, owned by this user (systemd --user reads it),
    # and never copied into the store.
    piWeb = {
      enable = true;
      environmentFile = osConfig.age.secrets.pi-web.path;
    };

    # REA registers as an MCP server for Pi / Pi Web / Codex / DSH and ships its
    # skill. `ghidra` also installs Ghidra + JDK 21 for the decompiler-backed
    # tools.
    rea = {
      enable = true;
      ghidra = true;
    };
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
