#!/usr/bin/env python3
"""Regenerates App/Resources/AppIcon.icon (Icon Composer / Liquid Glass bundle).

Usage: python3 Tools/AppIcon/make_icon.py <original-flat-icon.png> App/Resources/AppIcon.icon
Needs Pillow + numpy. The brand rainbow is sampled from the corners of the original icon;
Pokeball geometry, translucency and per-appearance behaviour are defined below.
"""
import json, math, os, sys
import numpy as np
from PIL import Image

SRC = sys.argv[1]            # original flat icon (brand colours are sampled from it)
OUT = sys.argv[2]            # .../AppIcon.icon
ASSETS = os.path.join(OUT, "Assets")
os.makedirs(ASSETS, exist_ok=True)

SIZE = 1024
C = SIZE / 2

# ---------- geometry (points on the 1024 canvas) ----------
RING_OUTER, RING_INNER = 360.0, 292.0        # outer ring annulus
BAND_HALF = 34.0                              # band thickness 68
BAND_REACH = RING_INNER + 2.0                 # band ends tuck 2pt under the ring
BTN_OUTER, BTN_INNER = 136.0, 70.0            # button annulus

def f(x): return f"{x:.2f}".rstrip("0").rstrip(".")

def circle(cx, cy, r, clockwise=True):
    sweep = 1 if clockwise else 0
    return (f"M {f(cx - r)} {f(cy)} A {f(r)} {f(r)} 0 1 {sweep} {f(cx + r)} {f(cy)} "
            f"A {f(r)} {f(r)} 0 1 {sweep} {f(cx - r)} {f(cy)} Z")

def rect(x1, y1, x2, y2):  # clockwise on screen
    return f"M {f(x1)} {f(y1)} L {f(x2)} {f(y1)} L {f(x2)} {f(y2)} L {f(x1)} {f(y2)} Z"

def svg(path):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}">\n'
            f'  <path fill="#FFFFFF" fill-rule="nonzero" d="{path}"/>\n</svg>\n')

# One silhouette (the original Pokeball shape): outer ring, the two band segments
# between ring and button, and the button ring. Nonzero winding; the holes are
# drawn counter-clockwise so the centre and the inside of the ring stay open.
band_end = math.sqrt(BTN_OUTER**2 - BAND_HALF**2)      # where the band meets the button
pokeball = " ".join([
    circle(C, C, RING_OUTER), circle(C, C, RING_INNER, clockwise=False),
    rect(C - BAND_REACH, C - BAND_HALF, C - band_end, C + BAND_HALF),
    rect(C + band_end, C - BAND_HALF, C + BAND_REACH, C + BAND_HALF),
    circle(C, C, BTN_OUTER), circle(C, C, BTN_INNER, clockwise=False),
])
with open(os.path.join(ASSETS, "pokeball.svg"), "w") as fh:
    fh.write(svg(pokeball))

# ---------- background: 4-corner rainbow sampled from the original ----------
src = Image.open(SRC).convert("RGB")
inset = 6
corners = {
    "tl": src.getpixel((inset, inset)),
    "tr": src.getpixel((SIZE - 1 - inset, inset)),
    "bl": src.getpixel((inset, SIZE - 1 - inset)),
    "br": src.getpixel((SIZE - 1 - inset, SIZE - 1 - inset)),
}
print("sampled corners:", corners, " centre:", src.getpixel((512, 512)))

ys, xs = np.mgrid[0:SIZE, 0:SIZE]
u = ((xs + 0.5) / SIZE)[..., None]
v = ((ys + 0.5) / SIZE)[..., None]
tl, tr, bl, br = (np.array(corners[k], dtype=np.float64) for k in ("tl", "tr", "bl", "br"))
base = (tl * (1 - u) + tr * u) * (1 - v) + (bl * (1 - u) + br * u) * v
d = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) / 0.5          # 0 centre .. 1 edge midpoints

def finish(rgb, lift, radius):
    k = lift * np.clip(1 - (d / radius) ** 2, 0, 1)
    rgb = rgb + (255 - rgb) * k
    return Image.fromarray(np.clip(rgb + 0.5, 0, 255).astype(np.uint8), "RGB")

# Light: the classic rainbow with a gentle luminous lift in the centre.
light = finish(base, lift=0.14, radius=0.8)
light.save(os.path.join(ASSETS, "rainbow.png"), optimize=True)

# Dark: the same rainbow pulled down to a deep "night" version, hues kept vivid.
gray = base.mean(axis=-1, keepdims=True)
dark = np.clip(gray + (base - gray) * 1.5, 0, 255) * 0.36
dark = finish(dark, lift=0.04, radius=0.8)
dark.save(os.path.join(ASSETS, "rainbow-dark.png"), optimize=True)

def srgb(c):
    return "extended-srgb:" + ",".join(f"{x / 255:.5f}" for x in c) + ",1.00000"

# ---------- icon.json ----------
pos = {"scale": 1, "translation-in-points": [0, 0]}

def glass_group(name, image, translucency):
    return {
        "layers": [{
            # White glass everywhere; Dark would otherwise inherit the icon's fill gradient.
            "fill-specializations": [
                {"value": "automatic"},
                {"appearance": "dark", "value": {"solid": "extended-gray:1.00000,1.00000"}},
            ],
            "glass": True, "image-name": image, "name": name, "position": dict(pos),
        }],
        "shadow": {"kind": "neutral", "opacity": 0.5},
        "translucency": {"enabled": True, "value": translucency},
    }

def flat_bg(name, image, visible_in):
    # Icon Composer's appearance ids: default (first entry, no key), "dark", and
    # "tinted" (the mono rendering that drives both Clear and Tinted on device).
    return {
        "fill": "none",
        "glass": False,
        "image-name": image,
        "name": name,
        "opacity-specializations": [{"value": 1 if "default" in visible_in else 0}]
        + [{"appearance": a, "value": 1 if a in visible_in else 0} for a in ("dark", "tinted")],
        "position": dict(pos),
    }

doc = {
    "fill": {"linear-gradient": [srgb(corners["tl"]), srgb(corners["br"])]},
    "groups": [
        glass_group("Pokeball", "pokeball.svg", 0.45),
        {
            "layers": [
                flat_bg("Rainbow", "rainbow.png", visible_in={"default"}),
                flat_bg("Rainbow Dark", "rainbow-dark.png", visible_in={"dark"}),
            ],
            "shadow": {"kind": "none", "opacity": 0.5},
            "translucency": {"enabled": False, "value": 0.5},
            "specular": False,
        },
    ],
    "supported-platforms": {"circles": ["watchOS"], "squares": "shared"},
}
with open(os.path.join(OUT, "icon.json"), "w") as fh:
    json.dump(doc, fh, indent=2)
    fh.write("\n")
print("wrote", OUT)
