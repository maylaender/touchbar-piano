#!/usr/bin/env python3
"""Builds the README images in docs/ from the CI `snapshot` artifact.

  gh run download <run-id> -n snapshot -D /tmp/snap     # or download the artifact zip
  pip install pillow
  python3 tools/readme_assets.py /tmp/snap               # needs node + playwright for docs/hero.png

Window/Touch Bar images are real app renders; only the MacBook in hero.png is an HTML illustration.
All images are saved without metadata (no ICC profile, no text chunks).
"""
import os, subprocess, sys
from PIL import Image, ImageDraw

src = sys.argv[1]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
out = os.path.join(root, "docs")

def save(im, name):
    im.info.pop("icc_profile", None)
    im.save(os.path.join(out, name), optimize=True)

def window(name):
    """Window screenshot, empty bottom cropped, rounded corners."""
    im = Image.open(f"{src}/window_{name}.png").convert("RGBA")
    w, h = im.size
    bg = im.getpixel((w // 2, h - 3))
    y = h - 1
    while y > 100 and all(abs(a - b) < 6 for x in range(20, w - 20, 7) for a, b in zip(im.getpixel((x, y))[:3], bg[:3])):
        y -= 1
    im = im.crop((0, 0, w, min(h, y + 22)))
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, im.size[0] - 1, im.size[1] - 1), 12, fill=255)
    im.putalpha(Image.composite(im.split()[3], Image.new("L", im.size, 0), mask))
    return im

def strip(name):
    """Touch Bar render on a black rounded bar."""
    tb = Image.open(f"{src}/touchbar_{name}.png").convert("RGBA")
    c = Image.new("RGBA", (tb.width + 20, tb.height + 20), (0, 0, 0, 0))
    ImageDraw.Draw(c).rounded_rectangle((0, 0, c.width - 1, c.height - 1), 14, fill=(0, 0, 0, 255))
    c.alpha_composite(tb, (10, 10))
    return c

for n in ["main", "sheet", "drums", "record", "dark"]:
    save(window(n), f"window-{n}.png")
for n in ["settings", "about"]:                       # small windows: keep as captured
    if os.path.exists(f"{src}/{n}.png"):
        save(Image.open(f"{src}/{n}.png"), f"{n}.png")
for n in ["main", "drums"]:
    save(strip(n), f"touchbar-{n}.png")

# demo.gif: header + falling notes from the window, Touch Bar below (frames f00..f35)
frames = []
for i in range(36):
    w = Image.open(f"{src}/window_f{i:02d}.png").convert("RGB")
    top = w.crop((0, 30, w.width, 325))
    tb = strip(f"f{i:02d}")
    tb = tb.resize((top.width - 40, int(tb.height * (top.width - 40) / tb.width)), Image.LANCZOS)
    f = Image.new("RGB", (top.width, top.height + tb.height + 30), (236, 236, 236))
    f.paste(top, (0, 0)); f.paste(tb, (20, top.height + 12), tb)
    frames.append(f.resize((f.width * 3 // 4, f.height * 3 // 4), Image.LANCZOS).convert("P", palette=Image.ADAPTIVE, colors=128))
frames[0].save(os.path.join(out, "demo.gif"), save_all=True, append_images=frames[1:], duration=330, loop=0, optimize=True)

# hero.png: real window + Touch Bar inside the MacBook illustration (tools/hero.html), rendered with Playwright
js = """
const {chromium}=require('playwright');(async()=>{const b=await chromium.launch();
const pg=await b.newPage({viewport:{width:1400,height:600},deviceScaleFactor:1.5});
await pg.goto('file://'+process.argv[1]);await pg.waitForLoadState('load');
const h=await pg.evaluate(()=>document.body.scrollHeight);await pg.setViewportSize({width:1400,height:h});
await pg.screenshot({path:process.argv[2],omitBackground:true});await b.close()})()"""
hero = os.path.join(out, "hero.png")
subprocess.run(["node", "-e", js, os.path.join(root, "tools", "hero.html"), hero], check=True)
save(Image.open(hero), "hero.png")
print("docs/ updated")
