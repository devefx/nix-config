# Media playback and audio/video tools
{pkgs, ...}: {
  home.packages = with pkgs; [
    pavucontrol
    playerctl
    pulsemixer
    pamixer # PulseAudio mixer CLI
    imv # simple image viewer
  ];

  programs.mpv = {
    enable = true;
    defaultProfiles = ["gpu-hq"];
    scripts = [pkgs.mpvScripts.mpris];
  };

  services.playerctld.enable = true;
}
