#!/usr/bin/env python3
"""Генератор процедурных ассетов СВЕТОБАЛАМУТА (спрайты, SFX, временная музыка).

Запуск из корня проекта:  python3 tools/gen_assets.py
Требует numpy и Pillow. Никакого ИИ: всё рисуется/синтезируется формулами.
"""
import math
import os
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
SFX = os.path.join(ROOT, "assets", "sfx")
MUS = os.path.join(ROOT, "assets", "music")
for d in (SPR, SFX, MUS):
    os.makedirs(d, exist_ok=True)

# ----------------------------------------------------------------- СПРАЙТЫ --
N = 128   # итоговый размер
SS = 4    # суперсэмплинг
W = N * SS


def P(x, y):
    """Единичные координаты (-1..1, вправо = нос существа) -> пиксели."""
    return (W / 2 + x * W / 2 * 0.88, W / 2 + y * W / 2 * 0.88)


class Art:
    def __init__(self):
        self.img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def poly(self, pts, fill=70, line=255, lw=7):
        pp = [P(*p) for p in pts]
        self.d.polygon(pp, fill=(255, 255, 255, fill))
        if line:
            self.d.line(pp + [pp[0]], fill=(255, 255, 255, line), width=lw, joint="curve")

    def path(self, pts, lw=7, a=255):
        pp = [P(*p) for p in pts]
        self.d.line(pp, fill=(255, 255, 255, a), width=lw, joint="curve")

    def dot(self, x, y, r, a=255):
        cx, cy = P(x, y)
        rr = r * W / 2
        self.d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 255, 255, a))

    def ell(self, cx, cy, rx, ry, fill=70, line=255, lw=7):
        pts = [(cx + rx * math.cos(t), cy + ry * math.sin(t))
               for t in np.linspace(0, 2 * math.pi, 48, endpoint=False)]
        self.poly(pts, fill, line, lw)

    def save(self, name):
        glow = self.img.filter(ImageFilter.GaussianBlur(9 * SS / 4))
        a = np.asarray(glow).astype(np.float32)
        a[..., 3] = np.clip(a[..., 3] * 1.1, 0, 255)
        glow = Image.fromarray(a.astype(np.uint8))
        out = Image.alpha_composite(glow, self.img)
        out = out.resize((N, N), Image.LANCZOS)
        out.save(os.path.join(SPR, name))


def mirror(pts):
    return [(x, -y) for x, y in pts]


def moth():
    a = Art()
    up = [(-0.05, -0.12), (-0.55, -0.98), (-0.98, -0.5), (-0.6, -0.02)]
    lo = [(-0.1, -0.1), (-0.45, -0.3), (-0.95, -0.15), (-0.4, 0.0)]
    for w in (up, mirror(up)):
        a.poly(w, 55)
    a.ell(-0.62, -0.5, 0.12, 0.12, 200, 255, 5)
    a.ell(-0.62, 0.5, 0.12, 0.12, 200, 255, 5)
    a.ell(0.0, 0.0, 0.55, 0.14, 150, 255, 8)
    a.dot(0.58, 0.0, 0.1)
    a.path([(0.6, -0.04), (0.95, -0.4)], 6)
    a.path([(0.6, 0.04), (0.95, 0.4)], 6)
    a.dot(0.95, -0.4, 0.04)
    a.dot(0.95, 0.4, 0.04)
    a.save("player_0.png")


def jelly():
    a = Art()
    for i, y0 in enumerate(np.linspace(-0.42, 0.42, 6)):
        pts = [(0.15 - 1.1 * t, y0 * (1 + 0.6 * t) + 0.12 * math.sin(t * 9 + i)) for t in np.linspace(0, 1, 18)]
        a.path(pts, 6, 220)
    bell = [(0.18 + 0.62 * math.cos(t), 0.72 * math.sin(t)) for t in np.linspace(-math.pi / 2, math.pi / 2, 28)]
    bell.append((0.0, 0.0))
    a.poly(bell + [(0.0, 0.5), (0.0, -0.5)], 80, 255, 8)
    a.ell(0.28, 0.0, 0.3, 0.3, 120, 255, 5)
    a.dot(0.4, 0.0, 0.1)
    a.save("player_1.png")


def fox():
    a = Art()
    tail = [(-0.4 - 0.5 * t, 0.55 * math.sin(t * 2.2) * t) for t in np.linspace(0, 1, 16)]
    a.path(tail, 14, 230)
    a.path(tail, 5)
    a.dot(*tail[-1], 0.08)
    a.ell(-0.15, 0.0, 0.5, 0.27, 100, 255, 7)
    head = [(0.98, 0.0), (0.42, -0.34), (0.22, -0.2), (0.22, 0.2), (0.42, 0.34)]
    a.poly(head, 130, 255, 8)
    ear1 = [(0.38, -0.3), (0.15, -0.72), (0.1, -0.2)]
    ear2 = mirror(ear1)
    a.poly(ear1, 160)
    a.poly(ear2, 160)
    a.dot(0.62, -0.1, 0.045)
    a.dot(0.62, 0.1, 0.045)
    a.dot(0.97, 0.0, 0.05)
    a.save("player_2.png")


def ray():
    a = Art()
    body = [(0.95, 0.0), (0.2, -0.45), (-0.1, -0.95), (-0.55, -0.5), (-0.4, 0.0),
            (-0.55, 0.5), (-0.1, 0.95), (0.2, 0.45)]
    a.poly(body, 70, 255, 8)
    a.path([(-0.4, 0.0), (-0.98, 0.0)], 8)
    a.path([(0.8, 0.0), (-0.3, 0.0)], 5, 200)
    for y in (-0.32, 0.32):
        a.path([(0.25, y * 0.4), (-0.15, y * 2.1)], 4, 180)
    a.dot(0.5, -0.1, 0.05)
    a.dot(0.5, 0.1, 0.05)
    a.ell(0.0, 0.0, 0.12, 0.12, 255, 255, 3)
    a.save("player_3.png")


def spider():
    a = Art()
    for sgn in (-1, 1):
        for i, ang in enumerate((-60, -25, 15, 55)):
            r = math.radians(ang)
            x1, y1 = 0.35 * math.cos(r), sgn * 0.35 * math.sin(abs(r)) * (1 if ang > 0 else 1)
            mid = (0.55 * math.cos(r) + 0.15, sgn * (0.6 + 0.05 * i))
            end = (0.95 * math.cos(r) - 0.15 * i + 0.2, sgn * (0.95 - 0.1 * i))
            a.path([(x1, y1), mid, end], 6)
    hexa = [(0.5 * math.cos(t), 0.5 * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 7)[:-1]]
    a.poly(hexa, 110, 255, 8)
    a.ell(-0.15, 0.0, 0.3, 0.26, 150, 255, 6)
    a.dot(0.3, -0.12, 0.07)
    a.dot(0.3, 0.12, 0.07)
    a.save("eater_0.png")


def maw():
    a = Art()
    pts = []
    for i in range(24):
        r = 0.95 if i % 2 == 0 else 0.55
        t = 2 * math.pi * i / 24
        pts.append((r * math.cos(t), r * math.sin(t)))
    a.poly(pts, 100, 255, 7)
    a.ell(0.0, 0.0, 0.38, 0.38, 20, 255, 5)
    a.dot(0.12, -0.12, 0.05)
    a.dot(0.12, 0.12, 0.05)
    a.path([(0.3, -0.1), (0.1, 0.0), (0.3, 0.1)], 5)
    a.save("eater_1.png")


for fn in (moth, jelly, fox, ray, spider, maw):
    fn()

# -------------------------------------------------------------------- SFX --
SR = 44100


def t_(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def env(n, a=0.003, power=3.0):
    e = (1 - np.linspace(0, 1, n)) ** power
    k = max(1, int(SR * a))
    e[:k] *= np.linspace(0, 1, k)
    return e


def chirp(f0, f1, dur, wave_="sq"):
    t = t_(dur)
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave_ == "sq":
        return np.sign(np.sin(ph))
    if wave_ == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    return np.sin(ph)


def noise(dur):
    return np.random.default_rng(7).uniform(-1, 1, int(SR * dur))


def save_wav(path, x, sr=SR):
    x = np.asarray(x, dtype=np.float32)
    x = x / max(1e-6, np.max(np.abs(x))) * 0.9
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def sfx(name, x):
    save_wav(os.path.join(SFX, name + ".wav"), x)


d = 0.1
sfx("shot", chirp(1900, 220, d) * env(int(SR * d), power=2.5))
d = 0.12
sfx("hit", (noise(d) * 0.7 + chirp(260, 60, d, "sin")) * env(int(SR * d), power=4))
d = 0.7
x = chirp(520, 35, d, "saw") * 0.8 + noise(d) * 0.4 * np.linspace(1, 0.1, int(SR * d))
sfx("death", x * env(int(SR * d), 0.002, 1.6))
d = 0.14
x = chirp(260, 1500, d, "sin") * 0.6 + noise(d) * 0.35 * np.linspace(0.2, 1, int(SR * d))
sfx("dash", x * np.sin(np.linspace(0, np.pi, int(SR * d))))
d = 0.8
t = t_(d)
mod = np.sin(2 * np.pi * 7 * t) * 6
x = np.sin(2 * np.pi * 180 * t + mod * np.sin(2 * np.pi * 90 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t))
x += 0.3 * chirp(900, 120, d, "sin")
sfx("possess", x * env(int(SR * d), 0.02, 1.2))
# хаос: быстрый подъём + арпеджио
seg = [chirp(180, 2600, 0.25, "saw") * env(int(SR * 0.25), power=0.6)]
for f in (440, 554, 659, 880, 1108):
    seg.append(chirp(f, f * 1.01, 0.07) * env(int(SR * 0.07), power=1.5))
sfx("chaos", np.concatenate(seg))
sfx("eat", np.concatenate([chirp(f, f, 0.045) * env(int(SR * 0.045), power=1.2) for f in (660, 880, 1320)]))
sfx("boom", (noise(0.9) * 0.9 + chirp(120, 25, 0.9, "sin")) * env(int(SR * 0.9), 0.002, 2.0))
sfx("click", chirp(1200, 900, 0.03) * env(int(SR * 0.03), power=1.0))
sfx("win", np.concatenate([chirp(f, f, 0.14, "sq") * env(int(SR * 0.14), power=1.2) for f in (523, 659, 784, 1046, 1318)]))

# ----------------------------------------------- ВРЕМЕННАЯ МУЗЫКА (loop) --
# Простой процедурный dnb-синтвейв-лупп: ЗАГЛУШКА, пока не положишь настоящий
# трек (CC0/CC-BY) в assets/music/ — игра подхватит любой .ogg/.mp3/.wav.
BPM = 172
step = int(SR * 60 / BPM / 4)
bars = 8
total = step * 16 * bars
mix = np.zeros(total, dtype=np.float32)


def add(buf, start, sig, gain=1.0):
    end = min(len(buf), start + len(sig))
    buf[start:end] += sig[: end - start] * gain


def kick():
    n = int(SR * 0.22)
    return chirp(150, 42, 0.22, "sin")[:n] * env(n, power=2)


def snare():
    n = int(SR * 0.18)
    return (noise(0.18)[:n] * 0.8 + chirp(230, 160, 0.18, "sin")[:n] * 0.5) * env(n, power=2.2)


def hat(open_=False):
    dd = 0.18 if open_ else 0.04
    n = int(SR * dd)
    nz = np.diff(np.concatenate([[0], noise(dd)[:n]]))
    return nz * env(n, power=3)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


prog = [33, 29, 31, 28, 33, 29, 31, 40]  # A1 F1 G1 E1 ...
arp = [0, 7, 12, 7, 15, 12, 7, 3]
lead_root = [57, 53, 55, 52, 57, 53, 55, 52]
for bar in range(bars):
    b0 = bar * 16 * step
    for s in (0, 10):
        add(mix, b0 + s * step, kick(), 1.0)
    for s in (4, 12):
        add(mix, b0 + s * step, snare(), 0.8)
    for s in (7, 15):
        add(mix, b0 + s * step, snare(), 0.18)
    for s in range(0, 16, 2):
        add(mix, b0 + s * step, hat(s == 14), 0.25 if s % 4 else 0.35)
    # reese-бас
    f = midi(prog[bar])
    dur = step * 16
    t = np.arange(dur) / SR
    bass = np.zeros(dur)
    for det in (-0.6, 0.0, 0.6):
        ph = 2 * np.pi * (f + det) * t
        bass += 2 * ((ph / (2 * np.pi)) % 1) - 1
    k = 40
    bass = np.convolve(bass, np.ones(k) / k, mode="same") * (0.55 + 0.25 * np.sin(2 * np.pi * 2 * t))
    add(mix, b0, bass.astype(np.float32), 0.55)
    # арпеджио-лид
    for s in range(16):
        note = lead_root[bar] + arp[s % 8] + (12 if s % 8 == 4 else 0)
        n = step
        ls = np.sign(np.sin(2 * np.pi * midi(note) * np.arange(n) / SR)) * env(n, power=1.8)
        add(mix, b0 + s * step, ls.astype(np.float32), 0.14 if s % 2 else 0.2)

save_wav(os.path.join(MUS, "placeholder_loop.wav"), mix)
print("ok: sprites, sfx, placeholder music ->", ROOT)
