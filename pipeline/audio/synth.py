"""Procedural fallback sounds (numpy/scipy). synth(kind, duration) returns a float mono array at SR."""
import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(1977)


def t(d): return np.arange(int(d * SR)) / SR
def noise(d): return rng.standard_normal(int(d * SR))
def lp(x, f, o=2): return signal.sosfilt(signal.butter(o, f, "low", fs=SR, output="sos"), x)
def hp(x, f, o=2): return signal.sosfilt(signal.butter(o, f, "high", fs=SR, output="sos"), x)
def bp(x, lo, hi, o=2): return signal.sosfilt(signal.butter(o, [lo, hi], "band", fs=SR, output="sos"), x)
def decay(d, tau): return np.exp(-t(d) / tau)


def env(d, a, r):
    n = int(d * SR); e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr) ** 2
    return e


def tone_sweep(d, f0, f1, harm=4):
    f = np.linspace(f0, f1, int(d * SR)); ph = 2 * np.pi * np.cumsum(f) / SR
    return sum(np.sin(ph * k) / k for k in range(1, harm + 1))


def synth(kind, d):
    n = int(d * SR); tt = t(d)
    if kind == "drill_motor_loop":
        x = sum(np.sin(2 * np.pi * f * tt) * g for f, g in [(50, 1), (100, .7), (150, .4), (200, .25), (310, .15)])
        return x + 0.25 * lp(noise(d), 600) + 0.15 * bp(noise(d), 1500, 2500) * (1 + .5 * np.sin(2 * np.pi * 25 * tt))
    if kind == "grind_soft_loop":
        return lp(noise(d), 700) * (1 + .4 * np.sin(2 * np.pi * 9 * tt)) + .3 * bp(noise(d), 100, 300)
    if kind == "grind_hard_loop":
        c = (np.sin(2 * np.pi * 35 * tt) > .6) * 1.0
        return lp(noise(d), 1200, 3) * (1 + .7 * np.sin(2 * np.pi * 14 * tt) ** 2) + .8 * lp(noise(d), 120) + .3 * bp(noise(d), 800, 3000) * c
    if kind == "grind_squeal_loop":
        f = 2200 + 250 * np.sin(2 * np.pi * 3 * tt) + 80 * lp(noise(d), 20)
        ph = 2 * np.pi * np.cumsum(f) / SR
        return np.sin(ph) + .5 * np.sin(2.01 * ph) + .3 * np.sin(3.02 * ph) + .2 * bp(noise(d), 2000, 6000)
    if kind == "drill_spin_down":
        return (tone_sweep(d, 220, 20, 5) + .3 * lp(noise(d), 500)) * env(d, .01, d * .6) * np.linspace(1, .2, n)
    if kind == "drill_spin_up":
        return (tone_sweep(d, 20, 220, 5) + .3 * lp(noise(d), 500)) * env(d, .05, .15)
    if kind == "pocket_burst":
        crack = hp(noise(d), 1500) * decay(d, .04) * 2
        gush = lp(noise(d), 4000) * (1 - np.exp(-tt / .1)) * np.exp(-tt / 1.0)
        return crack + 0.9 * gush + lp(noise(d), 120) * decay(d, .3) * 2
    if kind == "water_rush_loop":
        return lp(noise(d), 3500) * (1 + .3 * lp(noise(d), 8)) + .4 * hp(noise(d), 3000) * (1 + .5 * lp(noise(d), 15))
    if kind == "fire_crackle_loop":
        x = .25 * bp(noise(d), 200, 900) * (1 + .5 * lp(noise(d), 6))
        for _ in range(int(d * 28)):
            i = int(rng.integers(0, n - 800)); k = int(rng.integers(100, 700))
            x[i:i + k] += rng.uniform(.4, 1.5) * hp(rng.standard_normal(k), 1500) * np.exp(-np.arange(k) / (k / 4))
        return x
    if kind == "alarm_klaxon_loop":
        f = lp(np.where((tt % 1.0) < .55, 440.0, 330.0), 40, 1)
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = sum(np.sign(np.sin(ph * k)) / k for k in (1, 3, 5)) + .3 * np.sin(ph * 2)
        return lp(x, 3000) * (0.85 + .15 * np.sin(2 * np.pi * 90 * tt)) + .05 * noise(d)
    if kind == "hull_hit":
        body = sum(np.sin(2 * np.pi * f * tt) * g * np.exp(-tt / tau) for f, g, tau in
                   [(55, 2, .5), (110, 1, .6), (237, .7, .9), (412, .5, .7), (687, .3, .5), (1130, .2, .4)])
        return body + lp(noise(d), 600) * decay(d, .05) * 3
    if kind == "bracing_absorb":
        th = lp(noise(d), 200) * decay(d, .08) * 4 + np.sin(2 * np.pi * 60 * tt) * decay(d, .12) * 2
        f = 180 + 60 * np.sin(2 * np.pi * 2.3 * tt) + 40 * lp(noise(d), 10)
        cr = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR))
        cr = bp(cr, 200, 1400) * np.exp(-(tt - .35).clip(0) / .8) * (tt > .35)
        return th + .5 * cr
    if kind == "borer_fire":
        return (hp(noise(d), 800) * decay(d, .03) * 2 + lp(noise(d), 400) * decay(d, .12) * 2 + np.sin(2 * np.pi * 90 * tt) * decay(d, .1)
                + .5 * bp(noise(d), 2000, 5000) * decay(d, .02) * (tt > .06))
    if kind == "lance_fire_loop":
        return sum(np.sin(2 * np.pi * f * tt + k) for k, f in enumerate((100, 200, 301, 401, 802))) * (1 + .2 * np.sin(2 * np.pi * 7 * tt)) + .4 * bp(noise(d), 1500, 4000)
    if kind == "charge_fire":
        wh = bp(noise(d), 300, 3000) * np.exp(-((tt - .3) / .3) ** 2)
        return lp(noise(d), 300) * decay(d, .06) * 4 + np.sin(2 * np.pi * 70 * tt) * decay(d, .1) * 2 + wh * .8
    if kind == "charge_explosion":
        b = lp(noise(d), 250) * decay(d, .6) * 4 + np.sin(2 * np.pi * 40 * tt) * decay(d, .8) * 3
        crack = hp(noise(d), 1000) * decay(d, .06) * 2
        deb = np.zeros(n)
        for _ in range(60):
            i = min(int(rng.uniform(.3, 3) * SR), n - 600); k = 500
            deb[i:i + k] += rng.uniform(.1, .5) * bp(rng.standard_normal(k), 800, 4000) * np.exp(-np.arange(k) / 100)
        return b + crack + deb
    if kind == "bit_change":
        x = np.zeros(n)
        for i in range(5):
            s = int((.1 + .13 * i) * SR); k = 500
            x[s:s + k] += bp(rng.standard_normal(k), 1500, 6000) * np.exp(-np.arange(k) / 60) * 1.5
        m = tt >= 1.2; e = np.exp(-(tt - 1.2).clip(0) / .15) * m
        x += (np.sin(2 * np.pi * 95 * tt) + .5 * np.sin(2 * np.pi * 310 * tt)) * e * 2
        x += lp(noise(d), 500) * np.exp(-(tt - 1.2).clip(0) / .05) * m * 2
        return x
    if kind == "power_click":
        m = tt > .06
        return (lp(noise(d), 500) * decay(d, .02) * 3 + np.sin(2 * np.pi * 120 * tt) * decay(d, .05) * 2 +
                hp(noise(d), 2000) * decay(d, .004) * m * 1.5 + np.sin(2 * np.pi * 800 * tt) * decay(d, .01) * m)
    if kind == "ui_click":
        return hp(noise(d), 1500) * decay(d, .006) * 2 + np.sin(2 * np.pi * 1800 * tt) * decay(d, .01)
    if kind == "ui_hover":
        return hp(noise(d), 3000) * decay(d, .004) + np.sin(2 * np.pi * 2200 * tt) * decay(d, .006) * .3
    if kind == "typewriter_key":
        f = rng.uniform(1500, 2600)
        return (bp(noise(d), 1000, 5000) * decay(d, .008) * 2 + lp(noise(d), 300) * decay(d, .02) * 2 +
                np.sin(2 * np.pi * f * tt) * decay(d, .04) * .4)
    if kind == "radio_squelch":
        return hp(noise(d), 800) * (decay(d, .12) * 1.5 + .25 * (tt < .7)) * np.where(rng.random(n) > .9, 1.6, .7) * env(d, .002, .1)
    if kind == "radio_static_loop":
        return hp(lp(noise(d), 6000), 300) * (1 + .5 * lp(noise(d), 4)) + (rng.random(n) > .9995) * rng.standard_normal(n) * 6
    if kind == "pursuer_rumble_loop":
        sw = lp(noise(d), 2, 1); sw /= np.abs(sw).max()
        return ((np.sin(2 * np.pi * 28 * tt) + .6 * np.sin(2 * np.pi * 41 * tt + 1) + .4 * np.sin(2 * np.pi * 19 * tt))
                * (.6 + .4 * np.sin(2 * np.pi * .25 * tt) ** 2 + .3 * sw) + 1.5 * lp(noise(d), 70, 3))
    if kind == "hull_groan":
        f = 70 + 25 * np.sin(2 * np.pi * .4 * tt) + 15 * lp(noise(d), 4)
        ph = 2 * np.pi * np.cumsum(f) / SR
        x = sum(np.sin(ph * k * (1 + .003 * k)) / k for k in range(1, 9))
        return x * env(d, .6, 1.2) * (.7 + .3 * lp(noise(d), 6)) + .2 * lp(noise(d), 300) * env(d, .5, 1)
    if kind == "crew_hurt":
        return lp(noise(d), 350) * decay(d, .05) * 4 + np.sin(2 * np.pi * 85 * tt) * decay(d, .08) * 2
    raise KeyError(kind)
