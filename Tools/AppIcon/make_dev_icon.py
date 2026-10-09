#!/usr/bin/env python3
"""Generates DevIcon.icon: the "developer tool" variant of the Neodex app icon.

Usage: python3 Tools/AppIcon/make_dev_icon.py App/Resources/AppIcon.icon App/Resources/DevIcon.icon [--dark-background native|layer]

Same Liquid Glass Pokeball layer as the main icon (copied from the main bundle),
on the blueprint look of Apple's developer apps: a deep blue gradient with a fine
grid. The grid dims in Dark and stays faintly visible in Clear/Tinted (set
GRID_TINTED_OPACITY to 0 to hide it there like the rainbow in the main icon). Needs Pillow + numpy.
"""
import json, os, shutil, sys
import numpy as np
from PIL import Image, ImageDraw

MAIN = sys.argv[1]                       # .../AppIcon.icon (source of pokeball.svg)
OUT = sys.argv[2]                        # .../DevIcon.icon
DARK_BACKGROUND = "native"
if "--dark-background" in sys.argv:
    DARK_BACKGROUND = sys.argv[sys.argv.index("--dark-background") + 1]
ASSETS = os.path.join(OUT, "Assets")
os.makedirs(ASSETS, exist_ok=True)
shutil.copy(os.path.join(MAIN, "Assets", "pokeball.svg"), os.path.join(ASSETS, "pokeball.svg"))

SIZE = 1024
CELLS = 12                 # grid cells across the canvas
LINE = 3                   # line width in px at 1024
LINE_ALPHA = 64            # ~25 % white -> light blue on the gradient
GLOW_ALPHA = 0.12          # soft spotlight behind the glyph
GRID_DARK_OPACITY = 0.7    # grid strength in Dark
GRID_TINTED_OPACITY = 0.6  # grid strength in the mono rendering (Clear/Tinted on device)

# Blueprint blues (display-p3, top -> bottom).
LIGHT = ["display-p3:0.17000,0.46000,0.95000,1.00000", "display-p3:0.05000,0.20000,0.60000,1.00000"]
DARK = ["display-p3:0.05000,0.14000,0.38000,1.00000", "display-p3:0.01000,0.04000,0.14000,1.00000"]

# ---------- grid.png: transparent, white lines + centre glow ----------
ys, xs = np.mgrid[0:SIZE, 0:SIZE]
d = np.sqrt(((xs + 0.5) / SIZE - 0.5) ** 2 + ((ys + 0.5) / SIZE - 0.5) ** 2) / 0.5
glow_a = (GLOW_ALPHA * np.clip(1 - (d / 0.85) ** 2, 0, 1) * 255).astype(np.uint8)
glow = np.dstack([np.full((SIZE, SIZE), 255, np.uint8)] * 3 + [glow_a])
grid = Image.fromarray(glow, "RGBA")
lines = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(lines)
for i in range(1, CELLS):
    p = round(i * SIZE / CELLS) - LINE // 2
    draw.rectangle([p, 0, p + LINE - 1, SIZE - 1], fill=(255, 255, 255, LINE_ALPHA))
    draw.rectangle([0, p, SIZE - 1, p + LINE - 1], fill=(255, 255, 255, LINE_ALPHA))
grid = Image.alpha_composite(grid, lines)
grid.save(os.path.join(ASSETS, "grid.png"), optimize=True)

def p3(s):
    r, g, b, a = (float(x) for x in s.split(":")[1].split(","))
    return (r, g, b)

def gradient_png(top, bottom, path):
    t, b = np.array(p3(top)), np.array(p3(bottom))
    v = ((ys + 0.5) / SIZE)[..., None]
    rgb = (t * (1 - v) + b * v) * 255
    Image.fromarray(np.clip(rgb + 0.5, 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)

pos = {"scale": 1, "translation-in-points": [0, 0]}
flat_group = {"shadow": {"kind": "none", "opacity": 0.5}, "translucency": {"enabled": False, "value": 0.5}, "specular": False}

grid_layer = {
    "fill": "none", "glass": False, "image-name": "grid.png", "name": "Grid",
    "opacity-specializations": [{"value": 1}, {"appearance": "dark", "value": GRID_DARK_OPACITY}, {"appearance": "tinted", "value": GRID_TINTED_OPACITY}],
    "position": dict(pos),
}
pokeball_group = {
    "layers": [{
        "fill-specializations": [{"value": "automatic"}, {"appearance": "dark", "value": {"solid": "extended-gray:1.00000,1.00000"}}],
        "glass": True, "image-name": "pokeball.svg", "name": "Pokeball", "position": dict(pos),
    }],
    "shadow": {"kind": "neutral", "opacity": 0.5},
    "translucency": {"enabled": True, "value": 0.45},
}

doc = {"groups": [pokeball_group, {"layers": [grid_layer], **flat_group}],
       "supported-platforms": {"circles": ["watchOS"], "squares": "shared"}}
if DARK_BACKGROUND == "native":
    doc["fill-specializations"] = [{"value": {"linear-gradient": LIGHT}},
                                   {"appearance": "dark", "value": {"linear-gradient": DARK}}]
else:
    doc["fill"] = {"linear-gradient": LIGHT}
    gradient_png(DARK[0], DARK[1], os.path.join(ASSETS, "blueprint-dark.png"))
    doc["groups"].append({"layers": [{
        "fill": "none", "glass": False, "image-name": "blueprint-dark.png", "name": "Blueprint Dark",
        "opacity-specializations": [{"value": 0}, {"appearance": "dark", "value": 1}, {"appearance": "tinted", "value": 0}],
        "position": dict(pos)}], **flat_group})
# Keys sorted so the file matches Icon Composer's own ordering.
doc = json.loads(json.dumps(doc, sort_keys=True))
with open(os.path.join(OUT, "icon.json"), "w") as fh:
    json.dump(doc, fh, indent=2); fh.write("\n")
print("wrote", OUT, "dark background:", DARK_BACKGROUND)
