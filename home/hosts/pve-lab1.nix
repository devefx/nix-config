{
  imports = [
    ../linux/gui.nix
  ];

  modules.wechat.enable = true;
  modules.telegram.enable = true;
  modules.ayugram.enable = true;
}
