"""Turns the ElevenLabs recordings (folder 'Звуки взрывов', generated from docs/ELEVENLABS_PROMPTS.md)
into the game's sample assets under assets/audio/samples/ plus samples.json (the metadata the game
uses to level and adapt every sample, see scripts/audio/blast_samples.gd).

For each bomb:
  - the main hit is found near a hand-checked hint time (the generator put 0.3-9 s of silence or
    low pre-rumble before it, which nothing physical precedes: the ground tremor is a separate game
    layer); the sample starts 2 ms before the hit with a 2 ms fade-in;
  - trailing silence and extra late explosions the generator appended (Mk 84 at +14 s, Trinity at
    +20 s) are cut, the end fades out;
  - the sample is split into FRONT (the report and its body) and TAIL (the rolling rumble) with a
    complementary 0.3 s crossfade, so the game can change the direct-to-rumble balance with
    distance; the TAIL file keeps the full length with digital silence before the crossfade, so
    the game starts both files in the same frame and they stay sample-aligned at any time scale
    (front + tail at equal gain sum to the original);
  - metrics: max momentary loudness (ITU-R BS.1770 K-weighting, 400 ms), peak, band levels.
Extras: the megaton rumble bed (seamless loop), the bunker window rattle (decaying one-shot), the
rocket ignition (synthesized ignition overpressure + the recorded roar fading in) and the rocket
flight roar (seamless loop).

Usage: python tools/process_samples.py ["SOURCE_DIR"]   (needs numpy, scipy and ffmpeg with libvorbis)
"""
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "Звуки взрывов")
OUT = os.path.join(ROOT, "assets", "audio", "samples")
RATE = 48000

# (num, id, source file, hint of the main hit (s), hard end cut (s) or None)
# Trinity starts at its first, weaker thud (the prompt's 'two dull thuds in quick succession'),
# everything else at the main hit found near the hint.
START_AT_HINT = {"trinity"}
# recordings whose later, louder blow is intended (RDS-37's inversion-focused second blow, Ivy Mike's
# multipath arrival): not reported as an appended explosion
KEEP_LATER_BLOW = {"rds37", "ivy_mike"}
BOMBS = [
    (1, "mk82", "Mk 82", 3.94, None),
    (2, "mk84", "Mk 84", 7.59, 21.3),          # a second explosion starts at 21.5 s
    (3, "tallboy", "Tallboy", 3.01, None),
    (4, "grand_slam", "Grand Slam", 4.50, None),
    (5, "moab", "MOAB", 6.67, None),
    (6, "davy_crockett", "Davy Crockett", 4.91, None),
    (7, "foab", "FOAB", 8.63, None),
    (8, "b61_12", "B61-12", 4.21, None),
    (9, "grable", "Grable", 5.64, None),
    (10, "little_boy", "Little Boy", 3.18, None),
    (11, "trinity", "Trinity", 7.715, 26.9),     # 2 dull thuds (7.72, 7.90); a late explosion at 27.3 s
    (12, "baker", "Baker", 6.70, None),
    (13, "sedan", "Sedan", 1.10, None),
    (14, "ivy_king", "Ivy King", 7.50, None),
    (15, "b83", "B83", 7.62, None),
    (16, "rds37", "RDS-37", 4.00, None),         # first report; the focused second blow at +5.3 s stays
    (17, "ivy_mike", "Ivy Mike", 0.31, None),    # first report; the big arrival at +9.4 s stays
    (18, "castle_bravo", "Castle Bravo", 8.25, 26.5),   # an appended explosion starts at 26.65 s
    (19, "test219", "Test 219", 7.90, None),
    (20, "tsar", "Tsar Bomba", 9.20, None),
]
EXTRA = {
    "rumble": "Длинный раскат для мегатонных бомб",
    "ignite": "Зажигание и отрыв от стола",
    "loop": "Рёв в полёте, для петли",
    "rattle": "Треск окна бункера",
}
XFADE = 0.3          # front/tail crossfade (s)
CREST_MAX = 11.0     # peak minus max momentary loudness (dB): sharper samples are peak-limited so
                     # the game can reach their loudness target without clipping
LIMIT_MAX_DB = 6.0   # ...but never by more than this: deeper limiting flattens the report's crack


def read(path):
    with wave.open(path, "rb") as w:
        n, ch, sr, sw = w.getnframes(), w.getnchannels(), w.getframerate(), w.getsampwidth()
        raw = w.readframes(n)
    if sw != 2:
        raise ValueError(f"{path}: expected 16-bit PCM")
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    x = x.reshape(-1, ch)
    if ch == 1:
        x = np.repeat(x, 2, axis=1)
    if sr != RATE:
        g = np.gcd(sr, RATE)
        x = signal.resample_poly(x, RATE // g, sr // g, axis=0)
    return x


def write_wav(path, x, rate):
    y = np.clip(x, -1.0, 1.0)
    if y.ndim == 1:
        y = y[:, None]
    with wave.open(path, "wb") as w:
        w.setnchannels(y.shape[1])
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.round(y * 32767.0).astype(np.int16).tobytes())


def write_ogg(path, x, rate, q=6):
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        write_wav(tmp, x, rate)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis",
                        "-q:a", str(q), path], check=True)
    finally:
        os.remove(tmp)


def k_weight(x, fs):
    def rbj(kind, fc, q, gain_db):
        a = 10 ** (gain_db / 40.0)
        w0 = 2 * np.pi * fc / fs
        al = np.sin(w0) / (2 * q)
        c = np.cos(w0)
        if kind == "shelf":
            b = [a * ((a + 1) + (a - 1) * c + 2 * np.sqrt(a) * al), -2 * a * ((a - 1) + (a + 1) * c),
                 a * ((a + 1) + (a - 1) * c - 2 * np.sqrt(a) * al)]
            aa = [(a + 1) - (a - 1) * c + 2 * np.sqrt(a) * al, 2 * ((a - 1) - (a + 1) * c),
                  (a + 1) - (a - 1) * c - 2 * np.sqrt(a) * al]
        else:
            b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
            aa = [1 + al, -2 * c, 1 - al]
        return np.array(b) / aa[0], np.array(aa) / aa[0]
    b1, a1 = rbj("shelf", 1681.97, 0.7072, 4.0)
    b2, a2 = rbj("hp", 38.135, 0.5003, 0.0)
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def momentary(x, fs=RATE, win=0.4, hop=0.05):
    """Momentary loudness (LUFS) every hop over 400 ms windows, and the window start times."""
    y = k_weight(x if x.ndim == 2 else x[:, None], fs)
    p = np.sum(y * y, axis=1)
    n, h = int(win * fs), int(hop * fs)
    cs = np.concatenate([[0.0], np.cumsum(p)])
    st = np.arange(0, max(len(p) - n, 1), h)
    ms = (cs[np.minimum(st + n, len(p))] - cs[st]) / n
    return -0.691 + 10 * np.log10(ms + 1e-20), st / fs


def band_db(x, lo, hi):
    f, p = signal.welch(x.mean(axis=1) if x.ndim == 2 else x, fs=RATE, nperseg=8192)
    tot = np.sum(p) + 1e-30
    return round(float(10 * np.log10(np.sum(p[(f >= lo) & (f < hi)]) / tot + 1e-30)), 1)


def raised(n):
    return 0.5 - 0.5 * np.cos(np.pi * np.arange(n) / max(n, 1))


def find_onset(x, hint):
    a = np.abs(x).max(axis=1)
    lo, hi = int(max(hint - 0.35, 0.0) * RATE), int(min(hint + 0.6, len(a) / RATE) * RATE)
    pk = a[lo:hi].max()
    i_on = lo + int(np.argmax(a[lo:hi] >= 0.25 * pk))
    sm = np.convolve(a, np.ones(48) / 48.0, mode="same")          # 1 ms moving average
    j = i_on
    floor = 0.05 * pk
    while j > max(i_on - int(0.02 * RATE), lo) and sm[j] > floor:
        j -= 1
    return max(j - int(0.002 * RATE), 0)


def trim_end(x, cut):
    """Index after which only the decayed rumble / room tone remains (+1.5 s), bounded by cut."""
    n = len(x) if cut is None else min(len(x), int(cut * RATE))
    m = x[:n].mean(axis=1)
    h = int(0.25 * RATE)
    nb = n // h
    lv = 20 * np.log10(np.sqrt(np.mean(m[:nb * h].reshape(nb, h) ** 2, axis=1)) + 1e-12)
    top = lv.max()
    above = np.nonzero(lv > top - 46.0)[0]
    end = min(n, (int(above[-1]) + 1) * h + int(1.5 * RATE)) if len(above) else n
    return end


def check_appended(y, bid):
    """Warns about a new hit out of a quiet stretch (the generator sometimes appends a second
    explosion at the end): a 0.25 s level 25 dB over the quietest of the previous second, starting
    from below -40 dB re peak, later than 3 s after the start."""
    m = y.mean(axis=1)
    h = int(0.25 * RATE)
    nb = len(m) // h
    lv = 20 * np.log10(np.sqrt(np.mean(m[:nb * h].reshape(nb, h) ** 2, axis=1)) + 1e-12)
    top = lv.max()
    for k in range(12, nb):
        lo = lv[k - 4:k].min()
        if lo < top - 40.0 and lv[k] > lo + 25.0:
            print(f"WARNING {bid}: possible appended explosion at {k * 0.25:.2f} s (level {lv[k] - top:.1f} dB re peak)")
            return k * 0.25
    return None


def process_bomb(num, bid, fname, hint, cut):
    x = read(os.path.join(SRC, fname + ".wav"))
    s = int((hint - 0.002) * RATE) if bid in START_AT_HINT else find_onset(x, hint)
    e = trim_end(x, cut)
    y = x[s:e].copy()
    fi = int(0.002 * RATE)
    y[:fi] *= raised(fi)[:, None]
    fo = min(int(2.5 * RATE), len(y) // 3)
    y[-fo:] *= raised(fo)[::-1][:, None]
    y -= y.mean(axis=0)            # no DC
    mo, _ = momentary(y)
    crest = 20 * np.log10(np.abs(y).max()) - mo.max()
    limited = 0.0
    if crest > CREST_MAX + 0.1:
        # the limiter lowers the loudest window too: deepen it until the crest is reached
        y0 = y
        depth = min(crest - CREST_MAX, LIMIT_MAX_DB)
        for _ in range(8):
            y = limit_peaks(y0, np.abs(y0).max() * 10 ** (-depth / 20.0))
            mo, _ = momentary(y)
            c = 20 * np.log10(np.abs(y).max()) - mo.max()
            if c <= CREST_MAX + 0.1 or depth >= LIMIT_MAX_DB:
                break
            depth = min(depth + c - CREST_MAX, LIMIT_MAX_DB)
        limited = depth
    y *= 10 ** (-0.5 / 20.0) / np.abs(y).max()      # peak -0.5 dBFS
    if bid not in KEEP_LATER_BLOW:
        check_appended(y, bid)
    # split: where the 50 ms envelope after the loudest moment of the first 2.5 s falls 12 dB
    m = y.mean(axis=1)
    h = int(0.05 * RATE)
    nb = len(m) // h
    env = 20 * np.log10(np.sqrt(np.mean(m[:nb * h].reshape(nb, h) ** 2, axis=1)) + 1e-12)
    w2 = min(nb, int(2.5 / 0.05))
    k0 = int(np.argmax(env[:w2]))
    k = k0
    while k < nb - 1 and env[k] > env[k0] - 12.0:
        k += 1
    split = float(np.clip(k * 0.05, 0.6, 2.5))
    xa = int((split - XFADE / 2) * RATE)
    xb = int((split + XFADE / 2) * RATE)
    wt = np.zeros(len(y))
    wt[xb:] = 1.0
    wt[xa:xb] = np.linspace(0.0, 1.0, xb - xa, endpoint=False)
    front = (y * (1.0 - wt)[:, None])[:xb]
    tail = y * wt[:, None]           # full length: silence up to xa, then the crossfade and rumble
    base = f"{num:02d}_{bid}"
    write_ogg(os.path.join(OUT, "blast", base + "_front.ogg"), front, RATE)
    write_ogg(os.path.join(OUT, "blast", base + "_tail.ogg"), tail, RATE)
    mo, mt = momentary(y)
    mf, _ = momentary(front)
    mtl, _ = momentary(tail)
    r = {"num": num, "id": bid, "source": fname + ".wav", "src_start_s": round(s / RATE, 4),
         "src_end_s": round(e / RATE, 3), "dur_s": round(len(y) / RATE, 3), "limited_db": round(float(limited), 2),
         "front": f"res://assets/audio/samples/blast/{base}_front.ogg",
         "tail": f"res://assets/audio/samples/blast/{base}_tail.ogg",
         "split_s": round(split, 3), "xfade_start_s": round(xa / RATE, 4), "tail_offset_s": 0.0,
         "front_dur_s": round(len(front) / RATE, 3),
         "tail_dur_s": round(len(tail) / RATE, 3), "peak_dbfs": round(float(20 * np.log10(np.abs(y).max())), 2),
         "m_max": round(float(mo.max()), 2), "m_max_t": round(float(mt[np.argmax(mo)]), 2),
         "m_front": round(float(mf.max()), 2), "m_tail": round(float(mtl.max()), 2),
         "bands_db": {b: band_db(y[:int(2.0 * RATE)], *map(float, b.split("-"))) for b in
                      ["20-60", "60-150", "150-500", "500-2000", "2000-6000", "6000-20000"]}}
    print(f"{base:18s} start {r['src_start_s']:6.3f} end {r['src_end_s']:6.2f} dur {r['dur_s']:6.2f} split {split:4.2f} "
          f"peak {r['peak_dbfs']:6.2f} M {r['m_max']:6.2f}@{r['m_max_t']:5.2f} front {r['m_front']:6.2f} tail {r['m_tail']:6.2f}")
    return r


def limit_peaks(x, ceil, look=0.0015, release=0.08):
    """Look-ahead peak limiter: the needed gain is held at its minimum over the next `look` s and
    averaged over `look` s (a smooth ramp that is fully down when the peak arrives), then released
    with a one-pole of `release` s."""
    a = np.abs(x).max(axis=1)
    la = max(int(look * RATE), 1)
    need = np.minimum(1.0, ceil / np.maximum(a, 1e-12))
    h = need.copy()
    for k in range(1, la + 1):
        h[:-k] = np.minimum(h[:-k], need[k:])
    # moving average over the previous la samples: at a peak every averaged value is <= its need
    cs = np.concatenate([np.ones(la), h])
    c = np.cumsum(cs)
    s = (c[la:] - c[:-la]) / la
    out = np.empty_like(s)
    rel = np.exp(-1.0 / (release * RATE))
    cur = 1.0
    for i in range(len(s)):
        cur = s[i] if s[i] <= cur else s[i] + (cur - s[i]) * rel
        out[i] = cur
    return x * out[:, None]


def seamless_loop(x, a, b, xf, flatten=0.0, smooth=3.0, rate=RATE):
    """x[a:b] (x at `rate`) as a loop: optional partial envelope flattening, then an equal-power
    crossfade of the xf seconds after b into the start (noise-like material is uncorrelated across
    the seam). Resample BEFORE looping: resampling a finished loop zero-pads its ends (a click)."""
    seg = x[int(a * rate):int((b + xf) * rate)].copy()
    if flatten > 0.0:
        m = np.sqrt(np.mean(seg ** 2, axis=1) if seg.ndim == 2 else seg ** 2)
        k = int(smooth * rate)
        env = np.sqrt(np.convolve(m ** 2, np.ones(k) / k, mode="same")) + 1e-9
        g = (np.median(env) / env) ** flatten
        seg = seg * (g[:, None] if seg.ndim == 2 else g)
    n = int((b - a) * rate)
    nx = int(xf * rate)
    out = seg[:n].copy()
    t = np.arange(nx) / nx
    fin = np.sin(0.5 * np.pi * t)
    fout = np.cos(0.5 * np.pi * t)
    if out.ndim == 2:
        fin, fout = fin[:, None], fout[:, None]
    out[:nx] = seg[:nx] * fin + seg[n:n + nx] * fout
    return out


def main():
    os.makedirs(os.path.join(OUT, "blast"), exist_ok=True)
    # the raw downloads must never be imported by Godot (or shipped by export_filter=all_resources)
    gi = os.path.join(SRC, ".gdignore")
    if os.path.isdir(SRC) and not os.path.exists(gi):
        open(gi, "w").close()
    meta = {"rate": RATE, "xfade_s": XFADE, "bombs": {}, "extra": {}}
    for num, bid, fname, hint, cut in BOMBS:
        meta["bombs"][bid] = process_bomb(num, bid, fname, hint, cut)
    # megaton rumble bed: the steady part after the generator's own hit, evened out, looped
    x = read(os.path.join(SRC, EXTRA["rumble"] + ".wav"))
    x = signal.resample_poly(x, 1, 2, axis=0)               # 24 kHz: nothing above ~3 kHz in it
    lp = seamless_loop(x, 11.0, 27.0, 2.5, flatten=0.7, rate=RATE // 2)
    lp *= 0.7 / np.abs(lp).max()
    write_wav(os.path.join(OUT, "rumble_loop.wav"), lp, RATE // 2)
    mo, _ = momentary(signal.resample_poly(lp, 2, 1, axis=0))
    meta["extra"]["rumble_loop"] = {"path": "res://assets/audio/samples/rumble_loop.wav", "dur_s": round(len(lp) / (RATE / 2), 3),
                                    "m_mean": round(float(np.median(mo)), 2), "m_max": round(float(mo.max()), 2)}
    # bunker window rattle: a decaying one-shot
    x = read(os.path.join(SRC, EXTRA["rattle"] + ".wav"))[: int(2.6 * RATE)]
    t = np.arange(len(x)) / RATE
    env = (1.0 - np.exp(-t / 0.004)) * np.exp(-t / 0.55)
    y = x * env[:, None]
    fo = int(0.4 * RATE)
    y[-fo:] *= raised(fo)[::-1][:, None]
    y *= 0.9 / np.abs(y).max()
    write_ogg(os.path.join(OUT, "bunker_rattle.ogg"), y, RATE)
    mo, _ = momentary(y)
    meta["extra"]["rattle"] = {"path": "res://assets/audio/samples/bunker_rattle.ogg", "dur_s": round(len(y) / RATE, 3),
                               "m_max": round(float(mo.max()), 2)}
    # rocket ignition: ignition overpressure (positive triangle ~60 ms, negative half-sine ~120 ms,
    # 31 Hz ringing: research, as in AudioSynth.make_rocket_ignite) + the recorded roar building up
    # over ~0.3 s; it fades out from 4.0 to 6.5 s while the flight loop fades in
    x = read(os.path.join(SRC, EXTRA["ignite"] + ".wav")).mean(axis=1)
    n = int(6.5 * RATE)
    roar = x[:n].copy()
    t = np.arange(n) / RATE
    roar *= 1.0 - np.exp(-t / 0.30)
    k = np.zeros(n)
    tri, neg = int(0.06 * RATE), int(0.12 * RATE)
    k[:tri] = 1.0 - np.arange(tri) / tri
    k[tri:tri + neg] = -0.55 * np.sin(np.pi * np.arange(neg) / neg)
    k += 0.35 * np.sin(2 * np.pi * 31.0 * t) * np.exp(-t / 0.12)
    b, a = signal.butter(2, 18.0, "highpass", fs=RATE)
    k = signal.lfilter(b, a, k)
    y = roar + k * (np.abs(roar[: int(1.0 * RATE)]).max() * 1.1)
    fo0, fo1 = int(4.0 * RATE), n
    y[fo0:fo1] *= raised(fo1 - fo0)[::-1]
    y *= 0.9 / np.abs(y).max()
    write_ogg(os.path.join(OUT, "rocket_ignite.ogg"), y, RATE)
    mo, _ = momentary(np.repeat(y[:, None], 2, axis=1))
    meta["extra"]["rocket_ignite"] = {"path": "res://assets/audio/samples/rocket_ignite.ogg", "dur_s": round(n / RATE, 3),
                                      "m_max": round(float(mo.max()), 2), "fade_out_s": [4.0, 6.5]}
    # rocket flight roar: the steady stretch, looped (mono for AudioStreamPlayer3D, 32 kHz)
    x = read(os.path.join(SRC, EXTRA["loop"] + ".wav")).mean(axis=1)
    x = signal.resample_poly(x, 2, 3)
    lp = seamless_loop(x, 6.0, 13.0, 1.0, flatten=0.5, smooth=1.0, rate=32000)
    lp *= 0.9 / np.abs(lp).max()
    write_wav(os.path.join(OUT, "rocket_loop.wav"), lp, 32000)
    mo, _ = momentary(np.repeat(signal.resample_poly(lp, 3, 2)[:, None], 2, axis=1))
    meta["extra"]["rocket_loop"] = {"path": "res://assets/audio/samples/rocket_loop.wav", "dur_s": round(len(lp) / 32000, 3),
                                    "m_mean": round(float(np.median(mo)), 2), "m_max": round(float(mo.max()), 2)}
    for kx, v in meta["extra"].items():
        print(kx, v)
    with open(os.path.join(OUT, "samples.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print("WROTE", os.path.join(OUT, "samples.json"))


if __name__ == "__main__":
    main()
