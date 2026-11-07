"""Draws a review image for WAV files: waveform (linear), level envelope (dBFS) and a log-frequency
spectrogram, so synthesized sounds can be checked visually (tools/audio_preview.tscn writes them).
Usage: python tools/audio_plot.py file1.wav [file2.wav ...] --out sheet.png
Needs numpy and Pillow.
"""
import argparse
import wave

import numpy as np
from PIL import Image, ImageDraw


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, sw, rate, n = w.getnchannels(), w.getsampwidth(), w.getframerate(), w.getnframes()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    if ch == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    return x, rate


def panel(x, rate, title, w=1400, h=420):
    img = Image.new("RGB", (w, h), (12, 12, 14))
    d = ImageDraw.Draw(img)
    dur = len(x) / rate
    # waveform (top 120 px)
    cols = np.array_split(x, w)
    for i, c in enumerate(cols):
        if len(c) == 0:
            continue
        a, b = float(c.min()), float(c.max())
        d.line([(i, 60 - b * 55), (i, 60 - a * 55)], fill=(120, 200, 255))
    # level envelope dBFS (rms over 20 ms) in 120..200
    hop = max(1, int(0.02 * rate))
    env = [20 * np.log10(np.sqrt(np.mean(x[k:k + hop] ** 2)) + 1e-9) for k in range(0, len(x), hop)]
    pts = []
    for k, e in enumerate(env):
        px = int(k * hop / len(x) * w)
        py = 130 + int(np.clip(-e, 0, 80))
        pts.append((px, py))
    if len(pts) > 1:
        d.line(pts, fill=(255, 200, 80))
    for db in (0, 20, 40, 60, 80):
        d.text((2, 130 + db - 6), f"-{db}", fill=(90, 90, 90))
    # spectrogram 20 Hz..rate/2 log, rows 215..415
    nfft = 4096 if rate > 16000 else 2048
    hop2 = max(1, len(x) // w)
    win = np.hanning(nfft)
    fmin, fmax = 15.0, rate / 2
    sh = 200
    spec = np.zeros((sh, w))
    freqs = np.fft.rfftfreq(nfft, 1 / rate)
    rows_f = fmin * (fmax / fmin) ** (np.arange(sh)[::-1] / (sh - 1))
    idx = np.clip(np.searchsorted(freqs, rows_f), 1, len(freqs) - 1)
    xp = np.concatenate([np.zeros(nfft), x, np.zeros(nfft)])
    for i in range(w):
        s = int(i * len(x) / w)
        seg = xp[s + nfft // 2: s + nfft // 2 + nfft]
        if len(seg) < nfft:
            break
        mag = np.abs(np.fft.rfft(seg * win))
        spec[:, i] = 20 * np.log10(mag[idx] + 1e-9)
    mx = spec.max()
    norm = np.clip((spec - (mx - 80)) / 80, 0, 1)
    rgb = np.stack([norm ** 0.7 * 255, norm ** 1.5 * 230, (1 - norm) * norm * 4 * 200], axis=-1).astype(np.uint8)
    img.paste(Image.fromarray(rgb), (0, 215))
    for f in (20, 50, 100, 200, 500, 1000, 2000, 5000, 10000):
        if f < fmax:
            y = 215 + int((1 - np.log(f / fmin) / np.log(fmax / fmin)) * (sh - 1))
            d.text((2, y - 6), str(f), fill=(200, 200, 200))
    for s in range(int(dur) + 1):
        px = int(s / dur * w)
        d.line([(px, 205), (px, 212)], fill=(150, 150, 150))
    d.text((60, 2), f"{title}  ({dur:.1f} s, {rate} Hz, peak {20*np.log10(np.abs(x).max()+1e-9):.1f} dBFS)", fill=(255, 255, 255))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    panels = []
    for f in a.files:
        x, r = read_wav(f)
        panels.append(panel(x, r, f.replace("\\", "/").split("/")[-1]))
    h = sum(p.height for p in panels)
    sheet = Image.new("RGB", (panels[0].width, h))
    y = 0
    for p in panels:
        sheet.paste(p, (0, y))
        y += p.height
    sheet.save(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
