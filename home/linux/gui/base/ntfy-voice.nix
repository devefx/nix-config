{
  config,
  lib,
  pkgs,
  ...
}:
# ntfy -> Noctalia notifications, with offline Chinese speech for high-priority
# messages.
#
# Flow:
#
#   ntfy server --wss--> ntfy-voice.py --+--> D-Bus Notify --> Noctalia popup/history
#                                        |
#                                        +--> sherpa-onnx (matcha zh/en) --> pw-play
#
# Why WebSocket and not `ntfy subscribe`: this deployment puts ntfy behind an
# nginx that buffers the subscription HTTP stream. Measured against
# https://ntfy.yooke.top on 2026-10-27:
#
#   GET /anime_alerts/json            no headers at all, ever (curl -N, HTTP/1.1
#                                     and HTTP/2, both with and without ?since=)
#   GET /anime_alerts/sse             same
#   GET /anime_alerts/json?poll=1     200, returns the backlog
#   GET /anime_alerts/ws              101 Switching Protocols, messages arrive
#                                     within ~1s
#
# So `ntfy subscribe --from-config` (which only speaks /json) connects and then
# stays silent forever. The upstream fix is `proxy_buffering off` on the nginx
# side; until that happens the WebSocket endpoint is the one that works.
#
# Why not ntfy CLI env vars either way: the CLI does export NTFY_ID /
# NTFY_TITLE / NTFY_PRIORITY / NTFY_MESSAGE, but only for HTTP-stream events, so
# that path is unavailable here. The script parses the WebSocket JSON itself.
#
# --- Why the chaowen voice and not huayan -------------------------------------
#
# huayan (the obvious first pick) is unusable for speech, not merely "a bit
# robotic". Its config says phoneme_type = "espeak", so tones come from
# espeak-ng's `cmn` frontend, and that frontend collapses first and fourth tone
# onto the same output. Measured with espeak-ng 1.52:
#
#   ma1 -> mˈɑ5      ma4 -> mˈɑ5      (identical phonemes)
#   妈  -> mˈɑ5      骂  -> mˈɑ5
#
# Synthesised with noise_scale=0 / noise_w_scale=0 the two words come out
# bit-identical (max sample difference 0 over 9216 frames), and 14 of the 18
# tone marks in a sample alert sentence were the neutral tone. huayan is also
# "Finetuned from U.S. English lessac voice", so the tone information is absent
# from its training data as well -- the result is a real voice reciting flat.
#
# chaowen has phoneme_type = "pinyin" and goes through g2pW instead, which gets
# polyphones and tones right (重要 zhong4yao4, 重复 chong2fu4, 长江
# chang2jiang1, 长大 zhang3da4, 银行 yin2hang2, 行走 xing2zou3) and produces
# audibly distinct 妈/骂. Its model card is CC0 (xiao_ya, which it finetunes,
# is non-commercial), and it is 22.05 kHz like huayan.
#
# --- Why this needs a wrapper and a patched g2pW ------------------------------
#
# The pinyin path needs three things nixpkgs' piper-tts does not pull in by
# default: the [zh] extras (transformers, sentence-stream, unicode-rbnf), the
# g2pW ONNX model plus its lookup tables, and a BERT tokenizer. Upstream also
# downloads two of those at runtime, which a systemd unit should never do:
#
#   piper/phonemize_chinese.py  fetch+untar g2pw.tar.gz from huggingface
#   piper/g2pw_onnx.py          BertTokenizer.from_pretrained("bert-base-chinese")
#
# Both are pinned here instead. g2pW's config.py gets its model_source rewritten
# to the local tokenizer directory (that field is only ever passed to
# from_pretrained), and the run also sets HF_HUB_OFFLINE / TRANSFORMERS_OFFLINE
# so a future code path cannot silently reintroduce a network fetch. Verified
# with an unreachable proxy: synthesis still produces a valid WAV.
#
# Cost of the switch: the TTS closure grows from 1.0 GiB to 1.2 GiB and the
# first utterance takes ~1.5 s instead of ~0.8 s (g2pW ONNX + tokenizer load).
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;

  cfg = config.modules.ntfyVoice;

  # The same patched Noctalia build the session runs (see niri/noctalia.nix).
  # The IPC socket is looked up by the md5 of the config path baked into the
  # wrapper, so pointing the DND probe at any other noctalia-shell would fail
  # with "No running instances" and silently disable the check. `or null`
  # keeps this module importable without the niri option tree (Plasma hosts).
  noctaliaShell = config.modules.desktop.niri.noctaliaShell or null;

  # One bilingual model instead of two monolingual ones. Piper has no zh/en
  # model, so the previous setup had to split text by script and hand each run
  # to a different voice -- which audibly switched speaker mid-sentence
  # (measured median F0: chaowen 166 Hz for Chinese vs lessac 210 Hz for
  # English). matcha-icefall-zh-en is a single speaker trained on both
  # languages: same measurement gives 232 Hz / 250 Hz, i.e. one voice.
  #
  # It also removes a lot of machinery: no script splitting, no per-run piper
  # processes, no wav concatenation. sherpa-onnx synthesises the whole message
  # in one call at RTF ~0.03 (0.14 s for a 4.4 s sentence), against ~1.4 s of
  # fixed model-load cost per piper run.
  #
  # Cost: 16 kHz output instead of 22.05 kHz (8 kHz bandwidth instead of 11).
  # For spoken alerts that is not audible as a quality problem.
  matchaModel = pkgs.fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/matcha-icefall-zh-en.tar.bz2";
    hash = "sha256-JxuASvVwQA07zctTv25TzJ91GA7nY7nxPrXq8rDQhu8=";
  };

  # matcha is an acoustic model only; it needs a vocoder to produce audio.
  # README of the model names this exact file.
  matchaVocoder = pkgs.fetchurl {
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/vocoder-models/vocos-16khz-univ.onnx";
    hash = "sha256-tZkUKh+4/wPePoSsNf9TfGGeVvQmem/olIUaQoRKz54=";
  };

  # Everything sherpa-onnx reads at runtime, in one directory: the acoustic
  # model, tokens/lexicon, the espeak-ng data the lexicon falls back to, the
  # number/date FSTs, and the vocoder.
  ttsData = pkgs.runCommand "sherpa-tts-matcha-zh-en" { nativeBuildInputs = [ pkgs.bzip2 ]; } ''
    mkdir -p $out
    tar -xjf ${matchaModel} -C $out --strip-components=1
    ln -s ${matchaVocoder} $out/vocos-16khz-univ.onnx
  '';

  bridge = pkgs.writeShellApplication {
    name = "ntfy-voice";
    runtimeInputs = [
      # jeepney talks to org.freedesktop.Notifications directly: notify-send's
      # -A/--wait both blocks and reports expiries as clicks (see ntfy-voice.py).
      (pkgs.python3.withPackages (ps: [
        ps.websockets
        ps.jeepney
      ]))
      pkgs.sherpa-onnx # sherpa-onnx-offline-tts
      pkgs.pipewire # pw-play
      pkgs.xdg-utils # xdg-open, for the link button
    ]
    ++ optional (noctaliaShell != null) noctaliaShell; # `ipc call state all`, DND check
    text = ''
      exec python3 ${./ntfy-voice.py}
    '';
  };

  topicList = lib.concatStringsSep "," cfg.topics;
  priorityList = lib.concatStringsSep "," (map toString cfg.speakPriorities);
  speakAllTopicList = lib.concatStringsSep "," cfg.speakAllTopics;
in
{
  options.modules.ntfyVoice = {
    enable = mkEnableOption "ntfy desktop notifications with offline Chinese speech";

    host = mkOption {
      type = types.str;
      default = "https://ntfy.sh";
      example = "https://ntfy.example.com";
      description = "Base URL of the ntfy server.";
    };

    topics = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "anime_alerts" ];
      description = "Topics to subscribe to, one WebSocket per topic.";
    };

    speakPriorities = mkOption {
      type = types.listOf (types.ints.between 1 5);
      default = [
        4
        5
      ];
      description = ''
        ntfy priorities that are read aloud. Everything is still shown as a
        desktop notification; 1-3 are silent by default.
      '';
    };

    speakAllTopics = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "truenas-alerts" ];
      description = ''
        Topics whose messages are always spoken, ignoring `speakPriorities`.

        Meant for alert topics: a TrueNAS health notification arrives with no
        priority field at all (it parses as 0), so the priority rule alone would
        keep it silent. Listing the topic here makes every message on it spoken.
        Topics must still be in `topics` to be subscribed to.
      '';
    };

    voiceData = mkOption {
      type = types.path;
      default = ttsData;
      defaultText = lib.literalExpression "the pinned matcha-icefall-zh-en model";
      description = ''
        Directory holding the sherpa-onnx TTS assets: the acoustic model
        (`model-steps-3.onnx`), `tokens.txt`, `lexicon.txt`, `espeak-ng-data/`,
        the number/date FSTs, and the vocoder.

        Defaults to the pinned matcha-icefall-zh-en setup, a single speaker
        trained on both Chinese and English. That matters because the alternative
        -- one voice per language -- audibly switches speaker mid-sentence.
      '';
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = config.age.secrets.ntfy-token.path;
      description = ''
        File holding a ntfy access token, read at message time and sent as
        `Authorization: Bearer`. Kept out of the unit's environment and out of
        the Nix store; point it at an agenix secret when the server needs auth.
      '';
    };

    respectDoNotDisturb = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Skip speech while Noctalia's do-not-disturb (or performance mode) is on.
        The desktop notification is still delivered: Noctalia itself decides
        whether to pop it up. Requires `modules.desktop.niri`, which is what
        provides the noctalia-shell build to query; without it the check is
        skipped and alerts are always spoken.
      '';
    };

    maxSpokenChars = mkOption {
      type = types.ints.positive;
      default = 400;
      description = "Truncate longer messages before speaking them.";
    };
  };

  config = mkIf (cfg.enable && cfg.topics != [ ]) {
    home.packages = [ bridge ];

    systemd.user.services.ntfy-voice = {
      Unit = {
        Description = "ntfy notifications with offline Chinese TTS";
        Documentation = [ "https://docs.ntfy.sh/subscribe/api/" ];
        # Tied to the graphical session because notify-send needs a session bus
        # with Noctalia owning org.freedesktop.Notifications, and pw-play needs
        # the PipeWire socket from that session.
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${bridge}/bin/ntfy-voice";
        # The script reconnects on its own; this covers a crash or an OOM kill.
        Restart = "always";
        RestartSec = 10;

        Environment = [
          "NTFY_VOICE_HOST=${cfg.host}"
          "NTFY_VOICE_TOPICS=${topicList}"
          "NTFY_VOICE_SPEAK_PRIORITIES=${priorityList}"
          "NTFY_VOICE_SPEAK_ALL_TOPICS=${speakAllTopicList}"
          "NTFY_VOICE_VOICE_DATA=${cfg.voiceData}"
          "NTFY_VOICE_MAX_SPOKEN_CHARS=${toString cfg.maxSpokenChars}"
          "NTFY_VOICE_RESPECT_DND=${if cfg.respectDoNotDisturb && noctaliaShell != null then "1" else "0"}"
        ]
        ++ optional (noctaliaShell != null) "NTFY_VOICE_NOCTALIA_SHELL=${noctaliaShell}/bin/noctalia-shell"
        ++ optional (cfg.tokenFile != null) "NTFY_VOICE_TOKEN_FILE=${toString cfg.tokenFile}";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
