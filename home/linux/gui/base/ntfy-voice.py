"""ntfy -> desktop notification bridge, with offline Chinese TTS for alerts.

Subscribes to one WebSocket per topic and, for every message:

  * always posts a freedesktop notification via notify-send, which is what
    puts the message into Noctalia's popup/history (Noctalia owns
    org.freedesktop.Notifications);
  * speaks the message with Piper when its ntfy priority is in
    NTFY_VOICE_SPEAK_PRIORITIES, unless Noctalia reports do-not-disturb.

WebSocket, not the ntfy CLI: this server sits behind an nginx that buffers the
subscription HTTP stream, so /json, /sse and /raw never deliver anything while
/json?poll=1 and /ws do. See the module next to this file for the measurements.

All configuration comes from the environment (the systemd unit sets it), so the
script itself is a plain file rather than a Nix string.
"""

import fcntl
import json
import os
import queue
import re
import subprocess
import sys
import tempfile
import threading
import time
from collections import OrderedDict

from jeepney import DBusAddress, MatchRule, new_method_call
from jeepney.bus_messages import message_bus
from jeepney.io.blocking import open_dbus_connection
from websockets.sync.client import connect

HOST = os.environ.get("NTFY_VOICE_HOST", "https://ntfy.yooke.top").rstrip("/")
TOPICS = [
    topic.strip() for topic in os.environ.get("NTFY_VOICE_TOPICS", "").split(",") if topic.strip()
]
SPEAK_PRIORITIES = {
    int(value)
    for value in os.environ.get("NTFY_VOICE_SPEAK_PRIORITIES", "4,5").split(",")
    if value.strip()
}
# Topics whose messages are always spoken, whatever their priority. For alert
# topics (TrueNAS, backups) the absence of a priority must not mean silence.
SPEAK_ALL_TOPICS = {
    topic.strip()
    for topic in os.environ.get("NTFY_VOICE_SPEAK_ALL_TOPICS", "").split(",")
    if topic.strip()
}
# Directory holding the sherpa-onnx assets (acoustic model, tokens, lexicon,
# espeak-ng-data, number/date FSTs, vocoder). One bilingual model, so there is
# no second voice to point at.
VOICE_DATA = os.environ.get("NTFY_VOICE_VOICE_DATA", "")
# sherpa-onnx defaults to a single thread; two halves the latency for a few
# hundred MB of extra RSS and synthesis is only ~0.1 s anyway.
SYNTH_THREADS = int(os.environ.get("NTFY_VOICE_SYNTH_THREADS", "2"))
# matcha's default noise scale is 1.0, which makes the model improvise: the same
# "第一千三百二十一集" was rendered four different ways over five runs (三百 read
# as 百百, 八百, or dropped), because 三百 is rare enough in training that the
# sampler wanders. At 0.4 the same text was correct 5/5 while keeping some
# prosodic variation; 1.0 is what an alert must not do.
SYNTH_NOISE_SCALE = os.environ.get("NTFY_VOICE_NOISE_SCALE", "0.4")
TOKEN_FILE = os.environ.get("NTFY_VOICE_TOKEN_FILE", "")
MAX_SPOKEN_CHARS = int(os.environ.get("NTFY_VOICE_MAX_SPOKEN_CHARS", "400"))
# Bound on utterances waiting to be spoken. At ~5 s each, 8 is already ~40 s of
# backlog; beyond that the oldest alerts are dropped rather than spoken late.
MAX_SPEAK_QUEUE = int(os.environ.get("NTFY_VOICE_MAX_SPEAK_QUEUE", "8"))
# Bound on notification-id -> url entries kept for ActionInvoked lookups.
MAX_PENDING_LINKS = 200

URL_PATTERN = re.compile(r"https?://[^\s<>\"'`]+", re.IGNORECASE)
ENGLISH_PATTERN = re.compile(r"[A-Za-z]")
DIGIT_PATTERN = re.compile(r"\d")
DIGITS_PATTERN = re.compile(r"\d+")

NOTIFICATIONS = DBusAddress(
    "/org/freedesktop/Notifications",
    bus_name="org.freedesktop.Notifications",
    interface="org.freedesktop.Notifications",
)
RESPECT_DND = os.environ.get("NTFY_VOICE_RESPECT_DND", "1") == "1"
# Must be the *same* noctalia-shell build the running bar was started from: the
# IPC socket is looked up by the md5 of the config path baked into that wrapper,
# so an unpatched package would just answer "No running instances".
NOCTALIA_SHELL = os.environ.get("NTFY_VOICE_NOCTALIA_SHELL") or "noctalia-shell"

STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "ntfy-voice"
)
SEEN_FILE = os.path.join(STATE_DIR, "seen-ids")
SEEN_LIMIT = 500

# Speech is serialised (two overlapping utterances are unintelligible) but must
# not hold up the *notifications*: a burst of alerts would otherwise appear one
# per utterance-length, measured at 2.6 s apart with a 1.5 s synthesis + 1.1 s
# playback. Frames are queued here and the single worker in speak_worker drains
# them in order, which is what provides the serialisation.
speak_queue = queue.Queue(maxsize=MAX_SPEAK_QUEUE)


def log(message):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), message, file=sys.stderr, flush=True)


def enqueue_speech(topic, message):
    """Queue one utterance, dropping the oldest when a flood outpaces speech.

    Each utterance costs roughly (synthesis + playback) seconds, so a queue that
    grows without bound would keep speaking stale alerts long after the burst.
    Dropping the *oldest* keeps what is still actionable.
    """
    try:
        speak_queue.put_nowait((topic, message))
    except queue.Full:
        try:
            dropped = speak_queue.get_nowait()
            speak_queue.task_done()
            log("speech queue full, dropped " + str(dropped[1].get("id")))
        except queue.Empty:
            pass
        speak_queue.put_nowait((topic, message))


class SeenIds:
    """Message ids already handled, persisted so a restart does not re-speak.

    ntfy replays messages from `since=` on every reconnect, and this server has
    been observed to store the same publish more than once, so dedup is on the
    delivery path rather than bolted on afterwards.
    """

    def __init__(self, path, limit):
        self.path = path
        self.limit = limit
        self.ids = OrderedDict()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        try:
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    message_id = line.strip()
                    if message_id:
                        self.ids[message_id] = None
        except FileNotFoundError:
            pass

    def add(self, message_id):
        """Record message_id; False means it was already handled."""
        if not message_id:
            # Without a stable id there is nothing to compare against.
            return True
        if message_id in self.ids:
            return False
        self.ids[message_id] = None
        while len(self.ids) > self.limit:
            self.ids.popitem(last=False)
        try:
            with open(self.path + ".lock", "w", encoding="utf-8") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                temporary = self.path + ".tmp"
                with open(temporary, "w", encoding="utf-8") as handle:
                    handle.writelines(message_id + "\n" for message_id in self.ids)
                os.replace(temporary, self.path)
        except OSError as error:
            log("cannot persist seen ids: " + repr(error))
        return True


seen = SeenIds(SEEN_FILE, SEEN_LIMIT)


def auth_headers():
    if not TOKEN_FILE:
        return None
    try:
        with open(TOKEN_FILE, encoding="utf-8") as handle:
            token = handle.read().strip()
    except OSError as error:
        log("cannot read token file: " + repr(error))
        return None
    return {"Authorization": "Bearer " + token} if token else None


def quiet_now():
    """True when Noctalia is in do-not-disturb (or performance) mode.

    Best effort by design: after a rebuild the running bar may still be the
    previous store path, in which case the IPC call exits 255. Talking over a
    stale DND flag would silence alerts indefinitely, so a failed lookup means
    "not quiet".
    """
    if not RESPECT_DND:
        return False
    try:
        result = subprocess.run(
            [NOCTALIA_SHELL, "ipc", "call", "state", "all"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    if result.returncode != 0:
        return False
    try:
        state = json.loads(result.stdout).get("state") or {}
    except ValueError:
        return False
    return bool(state.get("doNotDisturb") or state.get("noctaliaPerformanceMode"))


def find_link(message):
    """Pick the URL to link to, or None.

    ntfy has a dedicated `click` field (set by the publisher's Click header) and
    that wins: it is an explicit intent, and it is the only place a URL survives
    when the body has been truncated for speech. Otherwise fall back to the
    first http(s) URL in the body.
    """
    click = message.get("click") or "".strip()
    if click.startswith(("http://", "https://")):
        return click
    match = URL_PATTERN.search(message.get("message") or "")
    return match.group(0).rstrip(".,;:!?)]}'\"") if match else None


def markdown_links(text):
    """Rewrite bare URLs as [url](url) so Noctalia renders them clickable.

    Noctalia only makes a notification's text clickable when
    notifications.enableMarkdown is on, and its sanitizeMarkdown() only rewrites
    explicit [label](url) pairs -- a bare https://... stays plain text and cannot
    be clicked (see NotificationHistoryPanel.linkAtPoint). ntfy bodies are plain
    text, so the link syntax is added here.
    """

    def replace(match):
        url = match.group(0)
        # Trailing punctuation is part of the sentence, not the URL.
        trimmed = url.rstrip(".,;:!?)]}'\"")
        suffix = url[len(trimmed) :]
        return "[" + trimmed + "](" + trimmed + ")" + suffix

    return URL_PATTERN.sub(replace, text)


class Notifier:
    """Sends freedesktop notifications and opens links when their button is hit.

    This talks DBus directly instead of shelling out to notify-send, for two
    reasons:

    * notify-send's -A/--wait blocks until the notification is closed, which
      would stall the WebSocket reader for the whole popup lifetime.
    * Worse, it reports a *click* for notifications that merely expired. Measured
      with -t 1500 and no interaction: notify-send printed "open" after 1.31 s,
      and with two actions it printed a random one. Reacting to that would open
      the link on every timeout.

    Talking DBus directly gives the notification id immediately and delivers
    ActionInvoked as a signal, so nothing blocks and only real clicks act.

    jeepney's blocking connection has no internal locking, so the listening side
    and the sending side each own their own connection. Sharing one was a real
    bug: send_and_get_reply() read from the same socket the listener was parked
    on, the listener swallowed the reply, and the connection stopped delivering
    anything -- alerts then silently stopped arriving while the WebSocket still
    looked healthy (TCP ESTAB, pings answered).
    """

    def __init__(self):
        self.lock = threading.Lock()
        self.links = {}  # notification id -> url, for ActionInvoked lookups
        self.listen_connection = None
        self.send_connection = None

    def _listen_connection(self):
        """Open the session bus and subscribe to ActionInvoked (idempotent)."""
        if self.listen_connection is not None:
            return self.listen_connection
        connection = open_dbus_connection(bus="SESSION")
        connection.send_and_get_reply(
            message_bus.AddMatch(
                MatchRule(
                    type="signal",
                    interface="org.freedesktop.Notifications",
                    member="ActionInvoked",
                )
            )
        )
        self.listen_connection = connection
        return connection

    def _listen(self):
        """Handle ActionInvoked forever, reopening the bus if it goes away."""
        while True:
            try:
                connection = self._listen_connection()
                message = connection.receive(timeout=1.0)
            except TimeoutError:
                continue
            except Exception as error:  # noqa: BLE001 - reconnecting is the recovery
                log("notification bus lost, reconnecting: " + repr(error))
                self.listen_connection = None
                time.sleep(2)
                continue
            if message.header.fields.get(3) != "ActionInvoked":
                continue
            notification_id, action = message.body
            with self.lock:
                url = self.links.pop(notification_id, None)
            if url is None or action not in ("open", "default"):
                continue
            log("opening " + url)
            try:
                # Setsid so the browser outlives this process and does not
                # receive our signals.
                subprocess.Popen(
                    ["xdg-open", url],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
            except (OSError, subprocess.SubprocessError) as error:
                log("xdg-open failed: " + repr(error))

    def start(self):
        threading.Thread(target=self._listen, name="notify-actions", daemon=True).start()

    def send(self, topic, message):
        priority = int(message.get("priority") or 0)
        title = (message.get("title") or "").strip() or "ntfy: " + topic
        body = (message.get("message") or "").strip() or title
        # Noctalia turns [label](url) into a clickable link once
        # notifications.enableMarkdown is on; ntfy bodies are plain text, so
        # rewrite the bare URLs before handing the text over. `click` is a URL
        # the body may not mention at all, so append it when it is not already
        # there -- otherwise the publisher's explicit target would be
        # unreachable from the notification.
        title = markdown_links(title)
        body = markdown_links(body)
        click = (message.get("click") or "").strip()
        if click.startswith(("http://", "https://")) and click not in body:
            body = body + "\n" + markdown_links(click)
        # ntfy priority and desktop urgency are different scales: 4 (high) and
        # 5 (urgent) become critical so Noctalia keeps the popup on screen longer.
        urgency = 2 if priority >= 4 else 1
        url = find_link(message)
        # `default` is what a click on the body itself activates; the named one
        # renders as a button. Both map to the same URL.
        actions = ["default", "打开链接", "open", "打开链接"] if url else []
        try:
            with self.lock:
                # Send connection is separate from the listener's; see the class
                # docstring for the bug that sharing one caused.
                if self.send_connection is None:
                    self.send_connection = open_dbus_connection(bus="SESSION")
                request = new_method_call(
                    NOTIFICATIONS,
                    "Notify",
                    "susssasa{sv}i",
                    (
                        "ntfy",
                        0,  # replaces nothing
                        "",  # no icon
                        title,
                        body,
                        actions,
                        {"urgency": ("y", urgency)},
                        -1,  # let the daemon pick the timeout
                    ),
                )
                notification_id = self.send_connection.send_and_get_reply(request, timeout=10).body[
                    0
                ]
                if url:
                    self.links[notification_id] = url
                    # Bound the map: an alert nobody clicks must not leak.
                    while len(self.links) > MAX_PENDING_LINKS:
                        self.links.pop(next(iter(self.links)))
        except Exception as error:  # noqa: BLE001 - a lost notification is not fatal
            log("notify failed: " + repr(error))
            # Drop the send connection so the next alert opens a fresh one.
            self.send_connection = None


notifier = Notifier()


def should_speak(topic, message):
    """Decide whether this message is read aloud.

    Priority alone is not enough: some topics are all-alerts. A TrueNAS health
    notification, for example, arrives with no priority at all (verified: the
    `priority` field is absent, so it parses as 0), and an alert topic like that
    wants every message spoken regardless. SPEAK_ALL_TOPICS overrides the
    priority rule for those; SPEAK_PRIORITIES still governs the rest.
    """
    if topic in SPEAK_ALL_TOPICS:
        return True
    return int(message.get("priority") or 0) in SPEAK_PRIORITIES


# A token that could be an identifier: ASCII letters/digits plus the separators
# they commonly carry (tank-01, v1.2.3, host:8080).
IDENTIFIER_TOKEN = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.\-/:]*")
# Dotted quad, e.g. 192.168.16.246.
IPV4_PATTERN = re.compile(r"\b\d{1,3}(?:\.\d{1,3}){3}\b")
# A standalone number, not glued to letters: "RAID 5", "共 1234 条".
STANDALONE_NUMBER = re.compile(r"(?<![A-Za-z0-9])\d+(?![A-Za-z0-9])")

CN_DIGITS = "零一二三四五六七八九"

# Emoji and pictographs. The model pronounces these by their English Unicode
# names, which wrecks an alert: "📢遮天更新了" became "lospeker 遮天更新了" and
# "✅ 备份完成" became "white heavy check mark 备份完成" (2.33 s against 1.34 s
# for the bare text). Ordinary punctuation is harmless by comparison -- 【】
# and ★ are simply skipped -- so only the pictographic blocks are removed.
EMOJI_PATTERN = re.compile(
    "["
    "\U0001f000-\U0001faff"  # mahjong, cards, enclosed, emoticons, transport, symbols
    "\U00002600-\U000027bf"  # misc symbols (⚠ ✅ ✨) and dingbats (✂ ➡)
    "\U00002b00-\U00002bff"  # misc symbols and arrows (⭐ ⬆)
    "\U0001f1e6-\U0001f1ff"  # regional indicators (flags)
    "\U0000fe00-\U0000fe0f"  # variation selectors
    "\U0000200d"  # zero-width joiner, used to glue emoji sequences
    "\U000020e3"  # combining enclosing keycap
    "]+"
)
CN_SECTION_UNITS = ["千", "百", "十", ""]
CN_SECTIONS = ["", "万", "亿", "万亿"]


def _section_to_chinese(section):
    """Render 0-9999 in Chinese, with the 十/一十 special case."""
    out = ""
    pending_zero = False
    for index, unit in enumerate(CN_SECTION_UNITS):
        digit = section // (10 ** (3 - index)) % 10
        if digit == 0:
            pending_zero = True
            continue
        if pending_zero and out:
            out += "零"
        out += CN_DIGITS[digit] + unit
        pending_zero = False
    # 10-19 read "十五", not "一十五".
    if out.startswith("一十"):
        out = out[1:]
    return out


def number_to_chinese(value):
    """Render a non-negative integer the way it is spoken, e.g. 1234 -> 一千二百三十四."""
    if value == 0:
        return "零"
    sections = []
    remaining = value
    while remaining > 0:
        sections.append(remaining % 10000)
        remaining //= 10000
    parts = []
    for index in range(len(sections) - 1, -1, -1):
        if sections[index] == 0:
            continue
        rendered = _section_to_chinese(sections[index])
        # A gap inside the number needs a 零: 10005 -> 一万零五.
        if parts and sections[index] < 1000:
            rendered = "零" + rendered
        parts.append(rendered + CN_SECTIONS[index])
    return "".join(parts)


def digits_to_chinese(digits):
    """Read every digit separately, e.g. 246 -> 二四六."""
    return " ".join(CN_DIGITS[int(character)] for character in digits)


def strip_emoji(text):
    """Drop pictographs, which the model reads aloud as their Unicode names."""
    stripped = EMOJI_PATTERN.sub("", text)
    return re.sub(r"\s+", " ", stripped).strip()


def localise_numbers(text):
    """Turn Arabic numerals into Chinese ones before synthesis.

    The model normalises digits to *English* words regardless of the surrounding
    language: "第 123 章" came back from ASR as "one hundred twenty three", and
    "共 1234 条记录" as "one thousand two hundred thirty four". For a Chinese
    alert that is the wrong language, and for identifiers it is also the wrong
    reading -- "mt1231231" was announced as the value 21,793,126,718.

    So digits are replaced outright rather than just separated:

    * A dotted quad is read digit by digit with 点 between the parts. Nobody
      says an address as a quantity, and as a number it took 6.4 s of audio.
    * Digits inside a token that also has letters are read digit by digit
      ("mt1231231" -> "mt 一 二 三 一 二 三 一"), because those are IDs and
      hostnames.
    * A standalone number is read as a value ("RAID 5" -> "RAID 五",
      "1234" -> "一千二百三十四"). Four or more digits with a leading zero are
      treated as a code instead, since 007 is not seven.
    """

    def repl_ip(match):
        # Keep the separators audible: 一 九 二 点 一 六 八 点 ...
        return " 点 ".join(digits_to_chinese(part) for part in match.group(0).split("."))

    def repl_identifier(match):
        token = match.group(0)
        if not (ENGLISH_PATTERN.search(token) and DIGIT_PATTERN.search(token)):
            return token

        def spell(run):
            digits = run.group(0)
            return " " + digits_to_chinese(digits) + " "

        spaced = DIGITS_PATTERN.sub(spell, token)
        return re.sub(r"\s+", " ", spaced).strip()

    def repl_number(match):
        digits = match.group(0)
        # Leading zero means a code, not a quantity: 007, 0123.
        if len(digits) > 1 and digits.startswith("0"):
            return digits_to_chinese(digits)
        # Beyond a few digits it is an ID rather than a countable amount.
        if len(digits) > 9:
            return digits_to_chinese(digits)
        return number_to_chinese(int(digits))

    text = IPV4_PATTERN.sub(repl_ip, text)
    text = IDENTIFIER_TOKEN.sub(repl_identifier, text)
    return STANDALONE_NUMBER.sub(repl_number, text)


def speak(topic, message):
    if not should_speak(topic, message):
        return
    # ntfy titles can carry hard line breaks (TrueNAS sends
    # "TrueNAS @ truenas  \n  \nThis is a test alert"), so collapse whitespace
    # rather than letting the model read the gaps as long pauses.
    text = " ".join(((message.get("title") or "") + "。" + (message.get("message") or "")).split())
    text = text.strip("。 ")
    if not text:
        return
    # Both must happen before truncation so the char budget counts what is
    # actually spoken. Emoji first: they are read as their Unicode names, which
    # is both wrong and long.
    text = localise_numbers(strip_emoji(text))
    if not text:
        return
    if len(text) > MAX_SPOKEN_CHARS:
        text = text[:MAX_SPOKEN_CHARS]
    if quiet_now():
        log("do not disturb is on, not speaking " + topic)
        return
    # Reaching here means the speak_worker is the only caller, so utterances are
    # already serialised; no lock needed.
    try:
        with tempfile.TemporaryDirectory(prefix="ntfy-voice-") as temporary:
            wav = os.path.join(temporary, "alert.wav")
            # One call for the whole message, Chinese and English alike:
            # matcha-icefall-zh-en is a single speaker trained on both. The
            # previous setup had to split by script and run one voice per run,
            # which switched speaker mid-sentence.
            synthesis = subprocess.run(
                [
                    "sherpa-onnx-offline-tts",
                    "--matcha-acoustic-model=" + os.path.join(VOICE_DATA, "model-steps-3.onnx"),
                    "--matcha-vocoder=" + os.path.join(VOICE_DATA, "vocos-16khz-univ.onnx"),
                    "--matcha-tokens=" + os.path.join(VOICE_DATA, "tokens.txt"),
                    "--matcha-lexicon=" + os.path.join(VOICE_DATA, "lexicon.txt"),
                    "--matcha-data-dir=" + os.path.join(VOICE_DATA, "espeak-ng-data"),
                    "--num-threads=" + str(SYNTH_THREADS),
                    "--matcha-noise-scale=" + SYNTH_NOISE_SCALE,
                    "--output-filename=" + wav,
                    text,
                ],
                # cwd stays at / under systemd; every path above is absolute, so
                # nothing depends on the working directory.
                capture_output=True,
                timeout=120,
                check=False,
            )
            if synthesis.returncode != 0 or not os.path.exists(wav):
                log(
                    "synthesis failed: "
                    + synthesis.stderr.decode("utf-8", "replace").strip()[-400:]
                )
                return
            subprocess.run(["pw-play", wav], timeout=120, check=False)
    except (OSError, subprocess.SubprocessError) as error:
        log("speech failed: " + repr(error))


def speak_worker():
    """Drain speak_queue forever, one utterance at a time."""
    while True:
        topic, message = speak_queue.get()
        try:
            speak(topic, message)
        except Exception as error:  # noqa: BLE001 - a bad utterance must not kill the worker
            log("speech worker: " + repr(error))
        finally:
            speak_queue.task_done()


def handle(topic, raw, since):
    """Handle one WebSocket frame, returning the new replay watermark."""
    try:
        message = json.loads(raw)
    except ValueError:
        log("ignoring non-JSON frame: " + raw[:120])
        return since
    if message.get("event") != "message":
        # "open" and keepalives carry no notification.
        return since
    try:
        stamp = int(message.get("time") or 0)
    except (TypeError, ValueError):
        stamp = 0
    watermark = max(since, stamp)
    message_id = message.get("id") or ""
    if not seen.add(message_id):
        log(topic + "/" + message_id + ": already handled, skipping")
        return watermark
    notifier.send(topic, message)
    # Queue rather than call: notify() must not wait for the previous utterance
    # to finish playing.
    enqueue_speech(topic, message)
    return watermark


def ws_url(topic, since):
    scheme = "wss" if HOST.startswith("https://") else "ws"
    url = scheme + "://" + HOST.split("://", 1)[-1] + "/" + topic + "/ws"
    if since:
        url += "?since=" + str(since)
    return url


def follow(topic):
    """Keep one topic subscribed forever, replaying whatever a drop missed."""
    since = 0
    backoff = 2
    while True:
        url = ws_url(topic, since)
        try:
            with connect(
                url,
                additional_headers=auth_headers(),
                open_timeout=20,
                ping_interval=30,
                ping_timeout=30,
                max_size=1 << 20,
                # Speech is serialised, so a burst can pile up behind the
                # current utterance; let the library buffer more than its
                # default 16 frames before it applies backpressure.
                max_queue=64,
            ) as socket:
                log("subscribed: " + url)
                backoff = 2
                for raw in socket:
                    if isinstance(raw, bytes):
                        raw = raw.decode("utf-8", "replace")
                    since = handle(topic, raw, since)
                log(topic + ": connection closed by server")
        except Exception as error:  # noqa: BLE001 - websockets has its own exception tree
            log(topic + ": connection failed: " + repr(error))
        time.sleep(backoff)
        backoff = min(backoff * 2, 60)


def main():
    if not TOPICS:
        raise SystemExit("NTFY_VOICE_TOPICS is empty")
    if not VOICE_DATA or not os.path.isdir(VOICE_DATA):
        raise SystemExit("NTFY_VOICE_VOICE_DATA is not a directory: " + VOICE_DATA)
    # Fail at startup rather than silently going quiet on the first alert.
    for required in (
        "model-steps-3.onnx",
        "vocos-16khz-univ.onnx",
        "tokens.txt",
        "lexicon.txt",
        "espeak-ng-data",
    ):
        if not os.path.exists(os.path.join(VOICE_DATA, required)):
            raise SystemExit("TTS asset missing from " + VOICE_DATA + ": " + required)
    log(
        "starting: host="
        + HOST
        + " topics="
        + ",".join(TOPICS)
        + " voice=matcha-icefall-zh-en"
        + " speak_priorities="
        + ",".join(str(priority) for priority in sorted(SPEAK_PRIORITIES))
        + " speak_all_topics="
        + (",".join(sorted(SPEAK_ALL_TOPICS)) or "-")
    )
    for topic in TOPICS:
        threading.Thread(target=follow, args=(topic,), name="ntfy-" + topic, daemon=True).start()
    threading.Thread(target=speak_worker, name="speak", daemon=True).start()
    notifier.start()
    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
