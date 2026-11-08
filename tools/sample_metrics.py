"""Offline check of the recorded blasts as the game plays them (BlastSamples plans).

Reads the plan grid written by tools/sample_plan_report.tscn (-- --json PLANS.json): for every bomb
the recommended distance x0.25..x4 at four times of day. Each plan is mixed the way sound_manager.gd
plays it - front at front_db, tail at tail_db from tail_offset_s, the BlastSmp EQ6 (modelled as a
graphic EQ: gains interpolated on a log-frequency axis between the band centres, zero phase), the
inversion echo (low-passed, delayed), the window rattle, the megaton rumble bed - over the bunker
ambience (vent / hum at VENT_DB / HUM_DB when VENT_ON / HUM_ON; both off in the game now; ducked like
_update_amb_mod), and measured:
  M_max     max momentary loudness (ITU-R BS.1770, 400 ms) of the mix, flat / desktop / laptop models
  over_amb  M_max minus the ambience alone (desktop; AMB_FLOOR -60 LUFS for a silent bunker), dB
  hiss      energy above 2 kHz relative to 60-500 Hz, 1-8 s after the arrival (desktop), dB
  boom_s    how long the momentary loudness stays within 10 dB of its maximum (desktop), s
Usage: python tools/sample_metrics.py PLANS.json AMBIENCE_DIR [--wav OUT_DIR] [--all]
  AMBIENCE_DIR holds vent.wav and hum.wav (tools/audio_preview.tscn -- --synth vent,hum --out DIR).
  Without --all only the recommended distance at the historical time of day plus a distance sweep
  at that time of day are printed.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process_samples as ps   # noqa: E402  (k-weighting, momentary loudness, wav i/o)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 48000
VENT_ON, HUM_ON, VENT_DB, HUM_DB = False, False, -30.0, -39.0     # scripts/audio/sound_manager.gd
AMB_FLOOR = -60.0          # 'over_amb' is measured against this when the bunker is silent
EQ_BANDS = [32.0, 100.0, 320.0, 1000.0, 3200.0, 10000.0]
_cache = {}


def res_path(p):
    return os.path.join(ROOT, p.replace("res://", "").replace("/", os.sep))


def load(path):
    """Decoded 48 kHz stereo float array of a res:// audio file (OGG via ffmpeg)."""
    if path in _cache:
        return _cache[path]
    src = res_path(path)
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-ar", str(RATE), "-ac", "2", tmp], check=True)
        with wave.open(tmp, "rb") as w:
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
    finally:
        os.remove(tmp)
    x = x.reshape(-1, 2)
    _cache[path] = x
    return x


def graphic_eq(x, gains_db):
    n = len(x)
    nf = 1 << int(np.ceil(np.log2(n + 1)))
    f = np.fft.rfftfreq(nf, 1.0 / RATE)
    lf = np.log(np.maximum(f, 1.0))
    g_db = np.interp(lf, np.log(EQ_BANDS), gains_db)
    g = 10 ** (g_db / 20.0)
    X = np.fft.rfft(x, nf, axis=0) * g[:, None]
    return np.fft.irfft(X, nf, axis=0)[:n]


def lowpass(x, fc):
    sos = signal.butter(2, fc, "lowpass", fs=RATE, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def playback(x, model):
    if model == "desktop":
        return signal.sosfilt(signal.butter(2, 80.0, "highpass", fs=RATE, output="sos"), x, axis=0)
    if model == "laptop":
        return signal.sosfilt(signal.butter(4, 180.0, "highpass", fs=RATE, output="sos"), x, axis=0)
    return x


def band_energy(x, lo, hi):
    f, p = signal.welch(x.mean(axis=1), fs=RATE, nperseg=4096)
    return float(np.sum(p[(f >= lo) & (f < hi)])) + 1e-30


def ambience(amb_dir, n, spl):
    out = np.zeros((n, 2))
    for name, db in ((("vent", VENT_DB),) if VENT_ON else ()) + ((("hum", HUM_DB),) if HUM_ON else ()):
        x, sr = None, None
        with wave.open(os.path.join(amb_dir, name + ".wav"), "rb") as w:
            sr = w.getframerate()
            ch = w.getnchannels()
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768.0
        x = x.reshape(-1, ch).mean(axis=1)
        g = np.gcd(sr, RATE)
        x = signal.resample_poly(x, RATE // g, sr // g)
        x = np.tile(x, n // len(x) + 1)[:n]
        out += (x * 10 ** (db / 20.0))[:, None]
    # duck (sound_manager._update_amb_mod), arrival at PRE
    dmax = float(np.clip(0.5 * (spl - 120.0), 0.0, 6.0))
    t = (np.arange(n) - PRE) / RATE
    d = np.where(t < 0, 0.0, np.where(t < 0.3, -dmax * np.clip(t / 0.01, 0, 1), -dmax * np.exp(-(t - 0.3) / 1.2)))
    return out * (10 ** (d / 20.0))[:, None]


PRE = int(1.0 * RATE)       # 1 s of ambience before the arrival


def mix(pl, extras):
    fr = load(pl["front"])
    tl = load(pl["tail"])
    toff = int(round(float(pl["tail_offset_s"]) * RATE))
    dur = max(len(fr), toff + len(tl)) + PRE + RATE
    ext = pl.get("ext") or {}
    if ext:
        dur = max(dur, PRE + int((float(ext["t0_s"]) + float(ext["dur_s"])) * RATE))
    dur = min(dur, PRE + 60 * RATE)
    y = np.zeros((dur, 2))
    gf = 10 ** (float(pl["front_db"]) / 20.0)
    gt = 10 ** (float(pl["tail_db"]) / 20.0)
    y[PRE:PRE + len(fr)] += fr * gf
    m = min(len(tl), dur - PRE - toff)
    y[PRE + toff:PRE + toff + m] += tl[:m] * gt
    y = graphic_eq(y, [float(g) for g in pl["eq_db"]])
    echo = pl.get("echo") or {}
    if echo:
        o = PRE + int(float(echo["delay_s"]) * RATE)
        e = lowpass(fr * 10 ** (float(echo["db"]) / 20.0), float(echo["lp_hz"]))
        m = min(len(e), dur - o)
        y[o:o + m] += e[:m]
    rt = pl.get("rattle") or {}
    if rt and "rattle" in extras:
        r = extras["rattle"] * 10 ** (float(rt["db"]) / 20.0)
        o = PRE + int(float(rt["delay_s"]) * RATE)
        m = min(len(r), dur - o)
        y[o:o + m] += r[:m]
    if ext and "rumble" in extras:
        lp = extras["rumble"]
        t0 = PRE + int(float(ext["t0_s"]) * RATE)
        n = dur - t0
        if n > 0:
            seg = np.tile(lp, (n // len(lp) + 1, 1))[:n]
            x = np.arange(n) / RATE
            env = np.clip(x / float(ext["att_s"]), 0, 1) ** 2 * (3 - 2 * np.clip(x / float(ext["att_s"]), 0, 1)) \
                * np.clip(1 - x / float(ext["dur_s"]), 0, 1) ** 1.4
            y[t0:] += seg * (env * 10 ** (float(ext["db"]) / 20.0))[:, None]
    return y


def metrics(pl, y, amb):
    out = {}
    tot = y + amb
    for model in ("phones", "desktop", "laptop"):
        mo, t = ps.momentary(playback(tot, model))
        out["M_" + model] = round(float(mo.max()), 1)
        if model == "desktop":
            ma, _ = ps.momentary(playback(amb, model))
            amb_l = max(float(np.median(ma)), AMB_FLOOR)
            out["amb"] = round(amb_l, 1)
            out["over_amb"] = round(float(mo.max() - amb_l), 1)
            above = t[mo >= mo.max() - 10.0]
            out["boom_s"] = round(float(above[-1] - above[0] + 0.4), 2) if len(above) else 0.0
            seg = playback(tot, model)[PRE + RATE:PRE + 8 * RATE]
            out["hiss"] = round(float(10 * np.log10(band_energy(seg, 2000, 16000) / band_energy(seg, 60, 500))), 1)
    out["peak"] = round(float(20 * np.log10(np.abs(tot).max() + 1e-12)), 1)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plans")
    ap.add_argument("amb_dir")
    ap.add_argument("--wav")
    ap.add_argument("--all", action="store_true")
    a = ap.parse_args()
    plans = json.load(open(a.plans, encoding="utf-8"))
    meta = json.load(open(os.path.join(ROOT, "assets", "audio", "samples", "samples.json"), encoding="utf-8"))
    extras = {"rattle": load(meta["extra"]["rattle"]["path"]), "rumble": load(meta["extra"]["rumble_loop"]["path"])}
    print(f"{'n':>2} {'id':13s} {'k':>4} {'tod':5s} {'km':>6} {'lufs':>6} {'M_flat':>6} {'M_desk':>6} {'M_lap':>6} "
          f"{'amb':>6} {'over':>5} {'hiss':>6} {'boom':>5} {'peak':>5}")
    rows = []
    for pl in plans:
        if not pl:
            continue
        ref = pl["tod"] == pl["ref_tod"] or (pl["ref_tod"] == "predawn" and pl["tod"] == "dawn")
        if not a.all and not ref:
            continue
        y = mix(pl, extras)
        amb = ambience(a.amb_dir, len(y), float(pl["spl_db"]))
        r = metrics(pl, y, amb)
        r.update({"id": pl["id"], "num": pl["num"], "k": pl["k"], "tod": pl["tod"], "km": round(float(pl["distance_m"]) / 1000.0, 1),
                  "lufs": round(float(pl["lufs"]), 1)})
        rows.append(r)
        print(f"{r['num']:2d} {r['id']:13s} {r['k']:4.2f} {r['tod']:5s} {r['km']:6.1f} {r['lufs']:6.1f} {r['M_phones']:6.1f} "
              f"{r['M_desktop']:6.1f} {r['M_laptop']:6.1f} {r['amb']:6.1f} {r['over_amb']:5.1f} {r['hiss']:6.1f} {r['boom_s']:5.2f} {r['peak']:5.1f}")
        if a.wav and pl["k"] == 1.0:
            os.makedirs(a.wav, exist_ok=True)
            ps.write_wav(os.path.join(a.wav, f"{r['num']:02d}_{r['id']}_{r['tod']}_game.wav"), np.clip(y + amb, -1, 1), RATE)
    json.dump(rows, open(os.path.splitext(a.plans)[0] + "_metrics.json", "w", encoding="utf-8"), indent=1)


if __name__ == "__main__":
    main()
