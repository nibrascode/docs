import sys
from art import *

def mask_for(style, s):
    im, d = canvas()
    if style == 'border8' or style == 'border6':
        inset, thick = 70, 150
        clip = band_clip(inset, thick)
        tile = tiling8 if style == 'border8' else tiling6
        st = strap(lambda dd, w: tile(dd, w, s, clip), 8, 3)
        band = rect_mask(inset, inset, W - inset, H - inset, [inset + thick, inset + thick, W - inset - thick, H - inset - thick])
        st = ImageChops.multiply(st, band)
        im = ImageChops.lighter(im, st)
        d = ImageDraw.Draw(im)
        rules(d, inset - 14, 3, 8); rules(d, inset + thick + 6, 3, 8)
    elif style == 'shamsa':
        st = strap(lambda dd, w: shamsa(dd, W / 2, H * 0.27, W * 0.2, w), 7, 2)
        im = ImageChops.lighter(im, st); d = ImageDraw.Draw(im)
        rules(d, 60, 3, 9)
    elif style == 'corners':
        R = W * 0.26
        st = strap(lambda dd, w: [shamsa(dd, x, y, R, w) for x, y in ((0, 0), (W, 0), (0, H), (W, H))], 7, 2)
        im = ImageChops.lighter(im, st); d = ImageDraw.Draw(im)
        rules(d, 60, 3, 9)
    elif style == 'field8':
        im = strap(lambda dd, w: tiling8(dd, w, s), 7, 3)
    elif style == 'field6':
        im = strap(lambda dd, w: tiling6(dd, w, s), 7, 3)
    elif style == 'headfoot':
        top = rect_mask(0, 80, W, 420); bot = rect_mask(0, H - 420, W, H - 80)
        st = strap(lambda dd, w: tiling8(dd, w, s), 7, 3)
        im = ImageChops.multiply(st, ImageChops.lighter(top, bot)); d = ImageDraw.Draw(im)
        for y in (66, 434, H - 434, H - 66):
            d.line([(60, y), (W - 60, y)], fill=255, width=3)
    return np.asarray(im.filter(ImageFilter.GaussianBlur(0.7)), np.float32) / 255

def make(rid, mat, col, vein, style, fin, tone, s, seed):
    if mat == 'leather': img = leather(seed, col)
    elif mat == 'linen': img = linen(seed, col)
    elif mat == 'suede': img = suede(seed, col)
    elif mat == 'silk': img = silk(seed, col)
    else: img = marble2(seed, col, vein)
    img = vignette(img, 0.30)
    m = mask_for(style, s)
    if fin == 'emboss':
        # fields fade under the title area
        if style.startswith('field'):
            y = np.linspace(0, 1, H)[:, None]; x = np.linspace(0, 1, W)[None, :]
            calm = np.clip(((np.abs(x - 0.5) / 0.36) ** 4 + (np.abs(y - 0.53) / 0.27) ** 4), 0, 1)
            m = m * (0.25 + 0.75 * calm)
        lum = float(np.mean(img)) / 255
        img = emboss(img, m, 0.30 if lum > 0.45 else 1.1)
    else:
        img = gild(img, m, seed + 1, tone)
    save(img, rid)

if __name__ == '__main__':
    import json
    for line in sys.argv[1:]:
        make(*json.loads(line))
