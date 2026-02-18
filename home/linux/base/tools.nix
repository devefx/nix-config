# Linux-only CLI tools
{pkgs, ...}: {
  home.packages = with pkgs; [
    libnotify
  ];

  # auto mount usb drives
  services.udiskie.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
