#!/usr/bin/env python3
"""Final step of the portfolio shots (chapter "Mám hru"): from the raw 2x renders in <raw> makes the delivered PNGs
in <out>: downscale (Lanczos) to 2560x1440, K2-01 at 21:9 (2520x1080 + a 3360x1440 master), the cursor in K2-07b,
the mask split for K2-09, the hero cards K2-10a/b on one canvas at one scale, a detail of the bar for K2-11a/b.

Usage: python3 tools/portfolio/finish.py <raw dir> <out dir> [figma card png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw

W, H = 2560, 1440
BG = (243, 239, 228)  # Royal Court Enamel canvas (ui_theme.gd CANVAS)


def load(raw, name):
    p = os.path.join(raw, name + ".png")
    return Image.open(p).convert("RGB") if os.path.exists(p) else None


def meta(raw, name):
    p = os.path.join(raw, name + ".json")
    return json.load(open(p)) if os.path.exists(p) else {}


def fit(im, w=W, h=H):
    """Scale to w x h (crop the centre if the aspect differs)."""
    src = im.width / im.height
    dst = w / h
    if abs(src - dst) > 0.002:
        if src > dst:
            nw = int(im.height * dst)
            x = (im.width - nw) // 2
            im = im.crop((x, 0, x + nw, im.height))
        else:
            nh = int(im.width / dst)
            y = (im.height - nh) // 2
            im = im.crop((0, y, im.width, y + nh))
    return im.resize((w, h), Image.LANCZOS)


def cursor(im, x, y, s=1.0):
    """A plain arrow cursor (white with a dark outline), tip at (x, y)."""
    pts = [(0, 0), (0, 34), (9, 26), (15, 40), (21, 37), (15, 24), (27, 24)]
    pts = [(x + px * s, y + py * s) for px, py in pts]
    d = ImageDraw.Draw(im)
    d.polygon(pts, fill=(255, 255, 255), outline=(20, 22, 26))
    d.line(pts + [pts[0]], fill=(20, 22, 26), width=max(2, int(2.5 * s)))
    return im


def card_canvas(card, radius=0):
    """A card centred on a 2560x1440 canvas in the UI's light colour; corners outside `radius` px are masked."""
    c = Image.new("RGB", (W, H), BG)
    mask = None
    if radius > 0:
        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius=radius, fill=255)
    c.paste(card.convert("RGB"), ((W - card.width) // 2, (H - card.height) // 2), mask)
    return c


def save(im, out, name):
    im.save(os.path.join(out, name + ".png"), optimize=True)
    print("OK", name, im.size)


def main():
    raw, out = sys.argv[1], sys.argv[2]
    figma = sys.argv[3] if len(sys.argv) > 3 else ""
    os.makedirs(out, exist_ok=True)

    # plain 16:9 shots
    for name in ["K2-03", "K2-04", "K2-06a", "K2-06b", "K2-07a", "K2-08", "K2-09", "K2-09-maska", "K2-11a", "K2-11b",
                 "K2-12", "K2-13", "K2-14", "K2-15", "K2-15b", "K2-16b", "K2-17", "K2-17b", "K2-18"]:
        im = load(raw, name)
        if im is not None:
            save(fit(im), out, name)

    # K2-01: 21:9 hero shot and a larger master
    im = load(raw, "K2-01")
    if im is not None:
        save(fit(im, 2520, 1080), out, "K2-01")
        save(fit(im, 3360, 1440), out, "K2-01-master-3360x1440")

    # K2-07a/b: cursor drawn where the order goes (position saved by the shot script, in raw pixels)
    for name in ["K2-07a", "K2-07b", "K2-16"]:
        im = load(raw, name)
        if im is None:
            continue
        m = meta(raw, name)
        k = W / m.get("vp", [im.width])[0]   # cursor positions are in the viewport's UI units (1600x900 with stretch)
        im = fit(im)
        if "cursor" in m:
            cursor(im, m["cursor"][0] * k, m["cursor"][1] * k, 1.6)
        save(im, out, name)

    # K2-09: side by side, the heroes in the game (left) and as the class colour mask (right), the same crop
    a, b = load(raw, "K2-09"), load(raw, "K2-09-maska")
    if a is not None and b is not None:
        # bounding box of the heroes from the mask (everything brighter than the dark floor)
        g = b.convert("L").point(lambda v: 255 if v > 60 else 0)
        x0, y0, x1, y1 = g.getbbox()
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        hw = max(x1 - x0, (y1 - y0) * 8 / 9) * 0.62   # half width with a margin; each half is 8:9
        hh = hw * 9 / 8
        box = (int(cx - hw), int(cy - hh), int(cx + hw), int(cy + hh))
        left = a.crop(box).resize((W // 2, H), Image.LANCZOS)
        right = b.crop(box).resize((W // 2, H), Image.LANCZOS)
        split = Image.new("RGB", (W, H))
        split.paste(left, (0, 0))
        split.paste(right, (W // 2, 0))
        ImageDraw.Draw(split).line([(W // 2, 0), (W // 2, H)], fill=BG, width=6)
        save(split, out, "K2-09-split")

    # K2-10a/b: the tank's hero card in Figma (screen "Battle · A Normal", 1600x900 frame, exported at any scale)
    # and in the game, both cut with the same margin (room for the selection marker above) and brought to
    # 3.2 px per UI point, centred on the same canvas. Plus the whole screens side by side at one scale.
    PAD_TOP, PAD = 0, 0             # UI points (the card only; the selection shows in its gilt frame)
    RADIUS = 9                      # card corner radius, UI points (the background outside is masked away)
    SCALE = 3.2                     # px per UI point in the delivered cards (the game's 2x render)
    FIGMA_CARD = (192, 735, 188, 149)   # node 40:170 in the frame, UI points
    fr = load(raw, "K2-10b_frame")
    if fr is not None:
        m = meta(raw, "K2-10b_frame")
        k = m.get("scale", fr.height / 900)
        x, y, w, h = [v / k for v in m["rect"]]
        card = fr.crop((round((x - PAD) * k), round((y - PAD_TOP) * k), round((x + w + PAD) * k), round((y + h + PAD) * k)))
        if abs(k - SCALE) > 0.01:
            card = card.resize((round(card.width * SCALE / k), round(card.height * SCALE / k)), Image.LANCZOS)
        save(card_canvas(card, round(RADIUS * SCALE)), out, "K2-10b")
        save(fit(fr), out, "K2-10b-obrazovka")
    if figma and os.path.exists(figma):
        fs = Image.open(figma).convert("RGB")
        k = fs.width / 1600
        x, y, w, h = FIGMA_CARD
        card = fs.crop((round((x - PAD) * k), round((y - PAD_TOP) * k), round((x + w + PAD) * k), round((y + h + PAD) * k)))
        card = card.resize((round(card.width * SCALE / k), round(card.height * SCALE / k)), Image.LANCZOS)
        save(card_canvas(card, round(RADIUS * SCALE)), out, "K2-10a")
        save(fit(fs), out, "K2-10a-obrazovka")
        print("   figma export at %.1fx" % k)

    # K2-11a/b: detail of the top bar, the same window for both (42 % of the width from the top edge)
    for name in ["K2-11a", "K2-11b"]:
        im = load(raw, name)
        box = meta(raw, name).get("bar")
        if im is None or not box:
            continue
        cx = box[0] + box[2] / 2
        bw = im.width * 0.42
        bh = bw * 9 / 16
        crop = im.crop((int(cx - bw / 2), 0, int(cx + bw / 2), int(bh)))
        save(crop.resize((W, H), Image.LANCZOS), out, name + "-detail")


if __name__ == "__main__":
    main()
