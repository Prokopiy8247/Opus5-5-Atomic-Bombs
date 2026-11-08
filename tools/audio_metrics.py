"""Objective loudness and spectrum metrics of the synthesized blast as the player hears it.

Reads the folder written by tools/audio_preview.tscn (bNN_*_front.wav, bNN_*_tail.wav and
manifest.json with the in-game playback levels), mixes front + tail exactly as sound_manager.gd
plays them (front at front_db, starting FRONT_PRE before the arrival; tail at front_db + tail_gain_db
from the arrival), and measures the mix through three playback models:
  phones   flat (headphones)
  desktop  2nd-order high-pass at 80 Hz (typical 2.0 desktop speakers / TV)
  laptop   4th-order high-pass at 180 Hz (laptop speakers)
Metrics per event (all levels in dBFS / LUFS of the game's output, before the master limiter):
  M_*      max momentary loudness (ITU-R BS.1770 K-weighting, 400 ms window, 50 ms hop)
  boom_s   how long the momentary loudness (desktop) stays within 10 dB of its maximum
  hiss     energy above 1 kHz relative to 60-500 Hz in the first 3 s after the arrival (desktop), dB
  tail_c   spectral centroid of the tail alone (0.3-4 s after the arrival), Hz
Usage: python tools/audio_metrics.py DIR [--json out.json] [--wav]   (--wav writes bNN_*_game.wav)
Needs numpy and scipy.
"""
import argparse
import json
import os
import wave

import numpy as np
from scipy import signal

RATE = 32000


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    if sw == 2:
        x = np.frombuffer(raw, dtype=np.int16).astype(np.float64) / 32768.0
    elif sw == 4:
        x = np.frombuffer(raw, dtype=np.int32).astype(np.float64) / 2147483648.0
    else:
        raise ValueError(f"{path}: {sw * 8}-bit not supported")
    x = x.reshape(-1, ch)
    if ch == 1:
        x = np.repeat(x, 2, axis=1)
    return x, rate


def resample(x, rate):
    if rate == RATE:
        return x
    g = np.gcd(rate, RATE)
    return signal.resample_poly(x, RATE // g, rate // g, axis=0)


def biquad_rbj(kind, fc, q, gain_db, fs):
    a = 10 ** (gain_db / 40.0)
    w0 = 2 * np.pi * fc / fs
    al = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    if kind == "shelf":
        b = [a * ((a + 1) + (a - 1) * c + 2 * np.sqrt(a) * al), -2 * a * ((a - 1) + (a + 1) * c),
             a * ((a + 1) + (a - 1) * c - 2 * np.sqrt(a) * al)]
        aa = [(a + 1) - (a - 1) * c + 2 * np.sqrt(a) * al, 2 * ((a - 1) - (a + 1) * c),
              (a + 1) - (a - 1) * c - 2 * np.sqrt(a) * al]
    else:  # high-pass
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
        aa = [1 + al, -2 * c, 1 - al]
    return np.array(b) / aa[0], np.array(aa) / aa[0]


def k_weight(x, fs):
    b1, a1 = biquad_rbj("shelf", 1681.9744509555319, 0.7071752369554193, 3.99984385397, fs)
    b2, a2 = biquad_rbj("hp", 38.13547087613982, 0.5003270373253953, 0.0, fs)
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def playback(x, model, fs):
    if model == "desktop":
        sos = signal.butter(2, 80.0, "highpass", fs=fs, output="sos")
        return signal.sosfilt(sos, x, axis=0)
    if model == "laptop":
        sos = signal.butter(4, 180.0, "highpass", fs=fs, output="sos")
        return signal.sosfilt(sos, x, axis=0)
    return x


def momentary(x, fs, win=0.4, hop=0.05):
    y = k_weight(x, fs)
    p = np.sum(y * y, axis=1)
    n = int(win * fs)
    h = int(hop * fs)
    cs = np.concatenate([[0.0], np.cumsum(p)])
    starts = np.arange(0, max(len(p) - n, 1), h)
    ms = (cs[np.minimum(starts + n, len(p))] - cs[starts]) / n
    return -0.691 + 10 * np.log10(ms + 1e-20), starts / fs


def band_energy(x, fs, lo, hi):
    f, pxx = signal.welch(np.mean(x, axis=1), fs=fs, nperseg=4096)
    m = (f >= lo) & (f < hi)
    return float(np.sum(pxx[m])) + 1e-30


def centroid(x, fs, lo=20.0):
    f, pxx = signal.welch(np.mean(x, axis=1), fs=fs, nperseg=2048)
    m = f >= lo
    return float(np.sum(f[m] * pxx[m]) / (np.sum(pxx[m]) + 1e-30))


def analyse(folder, e, write_wav=False):
    base = os.path.join(folder, e["base"])
    fr, rf = read_wav(base + "_front.wav")
    tl, rt = read_wav(base + "_tail.wav")
    fr = resample(fr, rf)
    tl = resample(tl, rt)
    pre = int(round(float(e["front_pre_s"]) * RATE))
    gf = 10 ** (float(e["front_db"]) / 20.0)
    gt = 10 ** ((float(e["front_db"]) + float(e["tail_gain_db"])) / 20.0)
    n = max(len(fr), pre + len(tl)) + RATE
    mix = np.zeros((n, 2))
    mix[:len(fr)] += fr * gf
    mix[pre:pre + len(tl)] += tl * gt
    if write_wav:
        y = np.clip(mix, -1, 1)
        with wave.open(base + "_game.wav", "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes((y * 32767).astype(np.int16).tobytes())
    out = {"num": e["num"], "id": e["id"], "km": e["km"], "spl_db": round(float(e["spl_db"]), 1),
           "front_db": round(float(e["front_db"]), 1), "peak_dbfs": round(20 * np.log10(np.abs(mix).max() + 1e-12), 1)}
    for model in ("phones", "desktop", "laptop"):
        m, t = momentary(playback(mix, model, RATE), RATE)
        out["M_" + model] = round(float(m.max()), 1)
        if model == "desktop":
            above = t[m >= m.max() - 10.0]
            out["boom_s"] = round(float(above[-1] - above[0] + 0.4), 2) if len(above) else 0.0
            seg = playback(mix, model, RATE)[pre:pre + 3 * RATE]
            out["hiss_db"] = round(10 * np.log10(band_energy(seg, RATE, 1000, 16000) / band_energy(seg, RATE, 60, 500)), 1)
    seg_t = tl[int(0.3 * RATE):int(4.0 * RATE)] * gt
    out["tail_c_hz"] = round(centroid(seg_t, RATE), 0)
    out["tail_rel_db"] = round(float(e["tail_gain_db"]), 1)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--json")
    ap.add_argument("--wav", action="store_true")
    a = ap.parse_args()
    with open(os.path.join(a.folder, "manifest.json"), encoding="utf-8") as f:
        man = json.load(f)
    rows = [analyse(a.folder, e, a.wav) for e in man]
    cols = ["num", "id", "km", "spl_db", "front_db", "peak_dbfs", "M_phones", "M_desktop", "M_laptop", "boom_s", "hiss_db", "tail_c_hz", "tail_rel_db"]
    print(" ".join(f"{c:>10}" for c in cols))
    for r in rows:
        print(" ".join(f"{str(r[c]):>10}" for c in cols))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=1)


if __name__ == "__main__":
    main()
