"""Live dictation: raw s16le 16 kHz mono on stdin -> one final line per phrase on stdout.

usage: stt_live.py MODEL DEVICE LANG CACHE_DIR [--partial] [--verbose]
Env knobs: STT_END (silence secs ending a phrase, 0.35), STT_PARTIAL (draft interval secs, 1.0),
           STT_FLOOR (min speech RMS, 0.01)
Partials go to stderr as a rewriting line; finals go to stdout.
"""
import sys, os, threading, queue, collections, time
import numpy as np
import openvino_genai as ov

model, device, lang, cache = sys.argv[1:5]
PARTIAL = "--partial" in sys.argv
VERBOSE = "--verbose" in sys.argv

SR, FRAME = 16000, 512                     # 32 ms frames
FPS = SR / FRAME
PRE = 8                                    # ~0.25 s pre-roll
END_SIL = max(1, int(float(os.environ.get("STT_END", "0.5")) * FPS))
MIN_VOICED = 6                             # ignore blips < ~0.2 s
MAX_FR = int(10 * FPS)                     # hard cut at 10 s keeps latency bounded
PARTIAL_EVERY = int(float(os.environ.get("STT_PARTIAL", "1.0")) * FPS)
FLOOR = float(os.environ.get("STT_FLOOR", "0.01"))
JUNK = {"", "you", "thank you.", "thanks for watching!", "."}


def log(m):
    print(m, file=sys.stderr, flush=True)


def load(dev):
    return ov.WhisperPipeline(model, dev, CACHE_DIR=cache)


log(f"loading {model} on {device} (first run compiles, cached afterwards)")
try:
    pipe = load(device)
except Exception as e:
    log(f"[{device} failed: {e}] falling back to CPU")
    pipe = load("CPU")

KW = {"task": "transcribe"}
if lang != "auto":
    KW["language"] = f"<|{lang}|>"


def transcribe(frames):
    x = np.concatenate(frames).astype(np.float32)
    return pipe.generate(x, **KW).texts[0].strip()


transcribe([np.zeros(FRAME * 10, np.float32)])      # warm-up: first real phrase isn't slow
log("ready - speak (Ctrl+C to stop)")

# --- worker: transcription never blocks the audio/VAD loop --------------------------------
jobs = queue.Queue()
cur = [0]                                            # current utterance id


def worker():
    while True:
        kind, uid, frames = jobs.get()
        if kind == "stop":
            return
        if kind == "partial" and (uid != cur[0] or not jobs.empty()):
            continue                                 # stale draft, skip
        t = time.time()
        text = transcribe(frames)
        if VERBOSE:
            log(f"\n[{kind} {time.time() - t:.2f}s for {len(frames) * FRAME / SR:.1f}s audio]")
        if kind == "partial":
            if uid == cur[0]:
                print("\r\033[K" + text, end="", file=sys.stderr, flush=True)
        else:
            if PARTIAL:
                print("\r\033[K", end="", file=sys.stderr, flush=True)
            if text.lower() not in JUNK:
                print(text, flush=True)


wt = threading.Thread(target=worker)
wt.start()

# --- reader thread: never lose audio -------------------------------------------------------
aq = queue.Queue()


def reader():
    rd = sys.stdin.buffer
    while True:
        b = rd.read(FRAME * 2)
        if len(b) < FRAME * 2:
            aq.put(None)
            return
        aq.put(np.frombuffer(b, np.int16).astype(np.float32) / 32768)


threading.Thread(target=reader, daemon=True).start()


def finish(buf, sil):
    keep = len(buf) - max(0, sil - 4)                # trim trailing silence, keep ~0.13 s
    jobs.put(("final", cur[0], buf[:keep]))
    cur[0] += 1


pre = collections.deque(maxlen=PRE)
buf, speaking, sil, voiced_n, last_partial = [], False, 0, 0, 0
noise = 0.005

while True:
    x = aq.get()
    if x is None:
        if speaking and voiced_n >= MIN_VOICED:
            finish(buf, sil)
        break
    rms = float(np.sqrt(np.mean(x * x)))
    voiced = rms > max(noise * 3.0, FLOOR)

    if not speaking:
        if voiced:
            speaking, buf, sil, voiced_n, last_partial = True, list(pre) + [x], 0, 1, 0
        else:
            pre.append(x)
            noise = 0.95 * noise + 0.05 * rms
        continue

    buf.append(x)
    sil = 0 if voiced else sil + 1
    voiced_n += voiced

    if sil >= END_SIL or len(buf) >= MAX_FR:
        if voiced_n >= MIN_VOICED:
            finish(buf, sil)
        pre = collections.deque(buf[-PRE:], maxlen=PRE)
        speaking, buf = False, []
    elif PARTIAL and len(buf) - last_partial >= PARTIAL_EVERY:
        last_partial = len(buf)
        jobs.put(("partial", cur[0], list(buf)))

jobs.put(("stop", 0, None))
wt.join()
