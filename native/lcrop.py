#!/usr/bin/env python3
# lcrop.py <out.png> <frame> <x0> <y0> <x1> <y1> <variant>... : same native-coordinate box from each replayed variant,
# scaled to a common size, side by side (labels on top)
import sys, os
from PIL import Image, ImageDraw
out, frame = sys.argv[1], int(sys.argv[2]); x0, y0, x1, y1 = map(int, sys.argv[3:7]); vs = sys.argv[7:]
O = os.path.expanduser('~/NBAStreetRecomp/dbz/gsdump/out')
W = 420; H = int(W * (y1 - y0) / (x1 - x0))
cols = min(len(vs), 3); rows = (len(vs) + cols - 1) // cols
img = Image.new('RGB', (W * cols, (H + 14) * rows), (40, 40, 40))
for i, v in enumerate(vs):
    im = Image.open(f'{O}/{v}/raditz_frame{frame:05d}.png') if os.path.exists(f'{O}/{v}/raditz_frame{frame:05d}.png') else Image.open(sorted(f'{O}/{v}/'+f for f in os.listdir(f'{O}/{v}') if f.endswith(f'{frame:05d}.png'))[0])
    s = im.size[1] / 448.0
    c = im.crop((int(x0 * s), int(y0 * s), int(x1 * s), int(y1 * s))).resize((W, H), Image.LANCZOS)
    img.paste(c, ((i % cols) * W, (i // cols) * (H + 14) + 14))
    ImageDraw.Draw(img).text(((i % cols) * W + 4, (i // cols) * (H + 14) + 1), v, fill=(255, 255, 0))
img.save(out)
