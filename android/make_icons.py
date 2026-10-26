#!/usr/bin/env python3
# make_icons.py <icon.png> <res dir>: the launcher icon from the runtime's icon.png, as macos/make_dist.sh makes the Mac
# app's (the art is not in the repository): an adaptive icon (the logo inside the safe zone, on the launcher's dark
# background) plus legacy icons (the logo on a dark rounded square) for every density. Needs Pillow.
import os, sys
from PIL import Image, ImageDraw

src, res = sys.argv[1], sys.argv[2]
img = Image.open(src).convert('RGBA')
logo = img.crop(img.getbbox())
BG = (14, 18, 26, 255)   # #0E121A, values/ic_launcher_background.xml


def place(size, frac):
    """the logo centred in a size x size canvas, its longer side frac of it"""
    c = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    s = frac * size / max(logo.size)
    l = logo.resize((max(1, round(logo.size[0] * s)), max(1, round(logo.size[1] * s))), Image.LANCZOS)
    c.alpha_composite(l, ((size - l.size[0]) // 2, (size - l.size[1]) // 2))
    return c


for d, k in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
    os.makedirs(f'{res}/mipmap-{d}', exist_ok=True)
    place(round(108 * k), 0.58).save(f'{res}/mipmap-{d}/ic_launcher_foreground.png')   # 108 dp, inside the 66 dp safe zone
    n = round(48 * k)
    icon = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    mask = Image.new('L', (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, n - 1, n - 1), radius=round(n * 0.22), fill=255)
    icon.paste(Image.new('RGBA', (n, n), BG), (0, 0), mask)
    icon.alpha_composite(place(n, 0.84))
    icon.save(f'{res}/mipmap-{d}/ic_launcher.png')
