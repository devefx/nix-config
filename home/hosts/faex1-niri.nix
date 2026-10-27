{
  imports = [ ./faex1.nix ];

  modules.desktop.niri.enable = true;

  # ntfy -> Noctalia notifications, with offline Chinese speech for priority
  # 4/5. Only on the niri variant: Noctalia is the notification daemon there,
  # and the TTS closure (piper + ONNX voice model + g2pW) is ~1.2 GiB that the
  # Plasma session does not need. The subscription uses WebSocket because this
  # server's nginx buffers the /json stream — see the module for measurements.
  #
  # `respectDoNotDisturb` stays at its default but has no effect until
  # modules.desktop.niri exposes `noctaliaShell`; without it the module skips
  # the check and always speaks (see the option's description).
  modules.ntfyVoice = {
    enable = true;
    host = "https://ntfy.yooke.top";
    topics = [
      "anime_alerts"
      "truenas-alerts"
    ];
    # Topics whose messages are always spoken, whatever their priority.
    # TrueNAS alerts carry no priority field at all, so the 4/5 rule would keep
    # them silent; anime_alerts is wanted aloud on every update too.
    speakAllTopics = [
      "truenas-alerts"
      "anime_alerts"
    ];
  };
}
