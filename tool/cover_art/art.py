"""Code-drawn premium cover artwork: materials + Islamic geometry, embossed or gilded."""
import math, sys, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

W, H = 1200, 1800          # render size (2:3), saved at 800x1200
rng = np.random.default_rng

def noise(seed, scale, w=W, h=H):
    """Smooth value noise via upsampled random grid."""
    r = rng(seed)
    gw, gh = max(2, int(w / scale)), max(2, int(h / scale))
    g = Image.fromarray((r.random((gh, gw)) * 255).astype(np.uint8))
    return np.asarray(g.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0

def fbm(seed, base, octaves=5):
    out = np.zeros((H, W), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        out += amp * noise(seed + o * 17, base / (2 ** o)); tot += amp; amp *= 0.5
    return out / tot

def hexrgb(h):
    h = h.lstrip('#'); return np.array([int(h[i:i+2], 16) for i in (0, 2, 4)], np.float32)

# ---------- materials ----------
def leather(seed, col):
    c = hexrgb(col)
    grain = fbm(seed, 26, 4)
    pores = noise(seed + 5, 3)
    cells = np.abs(noise(seed + 9, 14) - 0.5) * 2
    t = 0.55 * grain + 0.25 * cells + 0.20 * pores
    shade = 0.82 + 0.30 * (t - 0.5)
    return c[None, None, :] * shade[..., None]

def linen(seed, col):
    c = hexrgb(col); r = rng(seed)
    y = np.arange(H)[:, None]; x = np.arange(W)[None, :]
    warp = 0.5 + 0.5 * np.sin(x * 2 * math.pi / 5.0 + noise(seed, 40) * 6)
    weft = 0.5 + 0.5 * np.sin(y * 2 * math.pi / 5.0 + noise(seed + 1, 40) * 6)
    slub = noise(seed + 3, 2.5, W, H)
    t = 0.4 * warp + 0.4 * weft + 0.2 * slub
    shade = 0.88 + 0.16 * (t - 0.5) + 0.06 * (fbm(seed + 7, 300, 3) - 0.5)
    return c[None, None, :] * shade[..., None]

def marble(seed, col, vein):
    c = hexrgb(col); v = hexrgb(vein)
    y = np.arange(H)[:, None] / H; x = np.arange(W)[None, :] / W
    turb = fbm(seed, 220, 6)
    m = np.abs(np.sin((x * 3 + y * 5 + turb * 6.5) * math.pi))
    veins = np.clip(1 - m * 9, 0, 1) ** 1.5 + 0.35 * np.clip(1 - m * 3, 0, 1)
    cloud = fbm(seed + 3, 400, 4)
    base = c[None, None, :] * (0.9 + 0.2 * (cloud[..., None] - 0.5))
    return base * (1 - 0.7 * veins[..., None]) + v[None, None, :] * 0.7 * veins[..., None]

def suede(seed, col):
    c = hexrgb(col)
    t = 0.7 * fbm(seed, 120, 4) + 0.3 * noise(seed + 2, 2)
    return c[None, None, :] * (0.86 + 0.24 * (t - 0.5))[..., None]

def vignette(img, k=0.35):
    y = np.linspace(-1, 1, H)[:, None]; x = np.linspace(-1, 1, W)[None, :]
    d = np.sqrt(x ** 2 * 0.9 + y ** 2 * 0.7)
    return img * (1 - k * np.clip(d - 0.35, 0, 1) ** 1.4)[..., None]

# ---------- geometry (line masks, supersampled) ----------
def canvas():
    im = Image.new('L', (W, H), 0); return im, ImageDraw.Draw(im)

def star_poly(cx, cy, r, n=8, k=3, rot=0):
    pts = [(cx + r * math.cos(rot + 2 * math.pi * i / n), cy + r * math.sin(rot + 2 * math.pi * i / n)) for i in range(n)]
    segs = []
    for i in range(n):
        segs.append((pts[i], pts[(i + k) % n]))
    return segs

def girih8(d, s, lw, region=None):
    """Classic 8-point star & cross tiling."""
    for gy in range(-1, int(H / s) + 2):
        for gx in range(-1, int(W / s) + 2):
            cx, cy = gx * s + (s / 2 if gy % 2 else 0), gy * s * 0.5 * 2
            cx, cy = gx * s, gy * s
            if region and not region(cx, cy): continue
            for a, b in star_poly(cx, cy, s * 0.5, 8, 3, math.pi / 8):
                d.line([a, b], fill=255, width=lw)
            d.ellipse([cx - s * 0.12, cy - s * 0.12, cx + s * 0.12, cy + s * 0.12], outline=255, width=max(1, lw - 1))

def hex_rosettes(d, s, lw, region=None):
    """6-fold rosette lattice."""
    hgt = s * math.sqrt(3) / 2
    for gy in range(-1, int(H / hgt) + 2):
        for gx in range(-1, int(W / s) + 2):
            cx = gx * s + (s / 2 if gy % 2 else 0); cy = gy * hgt
            if region and not region(cx, cy): continue
            for a, b in star_poly(cx, cy, s * 0.5, 12, 5, 0):
                d.line([a, b], fill=255, width=lw)
            for a, b in star_poly(cx, cy, s * 0.26, 6, 2, math.pi / 6):
                d.line([a, b], fill=255, width=lw)

def medallion(d, cx, cy, R, lw, n=16):
    for ring, k in ((1.0, 7), (0.78, 5), (0.56, 3)):
        for a, b in star_poly(cx, cy, R * ring, n, k, math.pi / n):
            d.line([a, b], fill=255, width=lw)
    for rr in (1.06, 0.4, 0.18):
        d.ellipse([cx - R * rr, cy - R * rr, cx + R * rr, cy + R * rr], outline=255, width=lw)
    for i in range(n):  # petals
        a = 2 * math.pi * i / n
        x1, y1 = cx + R * 1.06 * math.cos(a), cy + R * 1.06 * math.sin(a)
        x2, y2 = cx + R * 1.28 * math.cos(a), cy + R * 1.28 * math.sin(a)
        d.line([(x1, y1), (x2, y2)], fill=255, width=lw)
        d.ellipse([x2 - R * 0.05, y2 - R * 0.05, x2 + R * 0.05, y2 + R * 0.05], outline=255, width=lw)

def arabesque_band(d, y0, y1, lw, period=150):
    """Interlaced vine scroll in a horizontal band."""
    mid = (y0 + y1) / 2; amp = (y1 - y0) * 0.32
    for phase in (0, math.pi):
        pts = [(x, mid + amp * math.sin(x * 2 * math.pi / period + phase)) for x in range(-20, W + 20, 3)]
        d.line(pts, fill=255, width=lw)
    for x in range(0, W + period, period // 2):
        sgn = 1 if (x // (period // 2)) % 2 else -1
        cx, cy = x + period / 4, mid + sgn * amp * 0.15
        r = amp * 0.55
        d.arc([cx - r, cy - r, cx + r, cy + r], 200 if sgn > 0 else 20, 340 if sgn > 0 else 160, fill=255, width=lw)
        d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=255)
    d.line([(0, y0), (W, y0)], fill=255, width=lw); d.line([(0, y1), (W, y1)], fill=255, width=lw)

def corner_pieces(d, m, size, lw):
    for (cx, cy, sx, sy) in ((m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)):
        for i in range(4):
            r = size * (1 - i * 0.22)
            d.arc([cx - r, cy - r, cx + r, cy + r], 0 if (sx, sy) == (1, 1) else 90 if (sx, sy) == (-1, 1) else 270 if (sx, sy) == (1, -1) else 180,
                  90 if (sx, sy) == (1, 1) else 180 if (sx, sy) == (-1, 1) else 360 if (sx, sy) == (1, -1) else 270, fill=255, width=lw)
        for a, b in star_poly(cx + sx * size * 0.42, cy + sy * size * 0.42, size * 0.3, 8, 3, math.pi / 8):
            d.line([a, b], fill=255, width=lw)

def mask_arr(im, blur=0.0):
    if blur: im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, np.float32) / 255.0

def center_calm(kind):
    """Region callbacks that keep the title area quiet."""
    if kind == 'full': return None
    if kind == 'edges':
        return lambda x, y: not (W * 0.16 < x < W * 0.84 and H * 0.24 < y < H * 0.80)
    if kind == 'top':
        return lambda x, y: y < H * 0.30
    if kind == 'bottom':
        return lambda x, y: y > H * 0.70
    return None

# ---------- finishes ----------
def emboss(img, m, depth=0.22):
    """Blind embossing: light from top-left."""
    mb = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6))
    a = np.asarray(mb, np.float32) / 255
    hl = np.roll(np.roll(a, -2, 0), -2, 1); sh = np.roll(np.roll(a, 2, 0), 2, 1)
    rel = (hl - sh)
    out = img * (1 + depth * rel[..., None]) * (1 - 0.10 * a[..., None])
    return out

def gild(img, m, seed, tone='gold'):
    pal = {'gold': ('#7a5a18', '#f6e3a1', '#b8913a'), 'rose': ('#7a4a35', '#f7d3bd', '#b97c62'),
           'silver': ('#6b6f76', '#f3f5f7', '#a3a8ae'), 'bronze': ('#5a3d1a', '#e2b77a', '#8e6431')}[tone]
    c0, c1, c2 = hexrgb(pal[0]), hexrgb(pal[1]), hexrgb(pal[2])
    y = np.linspace(0, 1, H)[:, None]; x = np.linspace(0, 1, W)[None, :]
    t = (x * 0.6 + y * 0.4 + 0.25 * fbm(seed, 260, 3)) % 1.0
    tri = np.abs(t * 2 - 1)   # 0..1..0 sweep
    foil = c0[None, None] * (1 - tri[..., None]) + c1[None, None] * tri[..., None]
    foil = foil * 0.75 + c2[None, None] * 0.25
    foil *= (0.92 + 0.16 * noise(seed + 4, 2))[..., None]
    a = m[..., None]
    # slight impression shadow under the foil
    sh = np.roll(np.roll(m, 2, 0), 2, 1)[..., None]
    base = img * (1 - 0.35 * sh)
    return base * (1 - a) + foil * a

def save(img, name):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((800, 1200), Image.LANCZOS)
    im.save(f'/workspace/cover-art/out/{name}.webp', 'WEBP', quality=80, method=6)

# ---------- v2 geometry: clean star outlines, strapwork, clipped bands ----------
def star_outline(cx, cy, R, n=8, ratio=0.54, rot=0):
    pts = []
    for i in range(2 * n):
        r = R if i % 2 == 0 else R * ratio
        a = rot + math.pi * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def strap(draw_fn, wide=9, narrow=3):
    """Double-line strapwork from any line drawing function(draw, width)."""
    a, da = canvas(); b, db = canvas()
    draw_fn(da, wide); draw_fn(db, narrow)
    return ImageChops.subtract(a, b)

def tiling8(d, w, s, clip=None):
    """8-point star & cross tiling as star outlines."""
    for gy in range(-1, int(H / s) + 2):
        for gx in range(-1, int(W / s) + 2):
            cx, cy = gx * s, gy * s
            if clip and not clip(cx, cy): continue
            pts = star_outline(cx, cy, s * 0.5, 8, 0.62, math.pi / 8)
            d.line(pts + [pts[0]], fill=255, width=w, joint='curve')

def tiling6(d, w, s, clip=None):
    hgt = s * math.sqrt(3) / 2
    for gy in range(-1, int(H / hgt) + 2):
        for gx in range(-1, int(W / s) + 2):
            cx = gx * s + (s / 2 if gy % 2 else 0); cy = gy * hgt
            if clip and not clip(cx, cy): continue
            pts = star_outline(cx, cy, s * 0.5, 6, 0.58, math.pi / 6)
            d.line(pts + [pts[0]], fill=255, width=w, joint='curve')
            pts = star_outline(cx, cy, s * 0.22, 6, 0.6, 0)
            d.line(pts + [pts[0]], fill=255, width=max(1, w - 1), joint='curve')

def shamsa(d, cx, cy, R, w):
    """Sun medallion: nested star outlines, petals and dotted ring."""
    for rr, n, ratio, rot in ((1.0, 16, 0.80, 0), (0.74, 12, 0.66, math.pi / 12), (0.48, 8, 0.6, math.pi / 8)):
        pts = star_outline(cx, cy, R * rr, n, ratio, rot)
        d.line(pts + [pts[0]], fill=255, width=w, joint='curve')
    for rr in (1.12, 0.26):
        d.ellipse([cx - R * rr, cy - R * rr, cx + R * rr, cy + R * rr], outline=255, width=w)
    for i in range(48):
        a = 2 * math.pi * i / 48; r0 = R * 1.22
        x, y = cx + r0 * math.cos(a), cy + r0 * math.sin(a)
        d.ellipse([x - w, y - w, x + w, y + w], fill=255)
    for i in range(16):  # lens petals
        a = 2 * math.pi * (i + 0.5) / 16
        pts = []
        for t in np.linspace(0, 1, 18):
            r = R * (1.28 + 0.22 * t)
            off = math.sin(t * math.pi) * 0.06
            pts.append((cx + r * math.cos(a + off), cy + r * math.sin(a + off)))
        for t in np.linspace(1, 0, 18):
            r = R * (1.28 + 0.22 * t)
            off = -math.sin(t * math.pi) * 0.06
            pts.append((cx + r * math.cos(a + off), cy + r * math.sin(a + off)))
        d.line(pts, fill=255, width=w, joint='curve')

def band_clip(inset, thick):
    def f(x, y):
        inner = (inset + thick < x < W - inset - thick) and (inset + thick < y < H - inset - thick)
        outer = (inset - 40 < x < W - inset + 40) and (inset - 40 < y < H - inset + 40)
        return outer and not inner
    return f

def rect_mask(x0, y0, x1, y1, inner=None):
    im, d = canvas(); d.rectangle([x0, y0, x1, y1], fill=255)
    if inner: d.rectangle(inner, fill=0)
    return im

def rules(d, inset, w, gap=10):
    for k in (0, gap):
        d.rectangle([inset + k, inset + k, W - inset - k, H - inset - k], outline=255, width=w)

def marble2(seed, col, vein):
    c = hexrgb(col); v = hexrgb(vein)
    y = np.arange(H)[:, None] / H; x = np.arange(W)[None, :] / W
    turb = fbm(seed, 500, 6)
    m = np.sin((x * 1.6 + y * 2.4 + turb * 3.2) * math.pi * 2)
    veins = np.exp(-(m / 0.06) ** 2)
    fine = np.exp(-((np.sin((x * 4 - y * 2 + fbm(seed + 9, 260, 5) * 4) * math.pi * 2)) / 0.03) ** 2) * 0.45
    vv = np.clip(veins + fine, 0, 1)
    vv = np.asarray(Image.fromarray((vv * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255
    cloud = fbm(seed + 3, 700, 4)
    base = c[None, None] * (0.93 + 0.14 * (cloud[..., None] - 0.5))
    return base * (1 - 0.8 * vv[..., None]) + v[None, None] * 0.8 * vv[..., None]

def silk(seed, col):
    c = hexrgb(col)
    y = np.arange(H)[:, None]; x = np.arange(W)[None, :]
    wob = fbm(seed, 380, 4)
    moire = np.sin(y * 0.55 + wob * 40) * np.sin(y * 0.58 + x * 0.02 + wob * 34)
    sheen = 0.5 + 0.5 * np.sin((x / W * 1.3 + y / H * 0.7 + wob * 0.6) * math.pi)
    shade = 0.90 + 0.035 * moire + 0.12 * (sheen - 0.5)
    return c[None, None] * shade[..., None]

def tiling8(d, w, s, clip=None):
    """Interlocking 8-point stars (tips meet, crosses form between)."""
    for gy in range(-1, int(H / s) + 2):
        for gx in range(-1, int(W / s) + 2):
            cx, cy = gx * s, gy * s
            if clip and not clip(cx, cy): continue
            pts = star_outline(cx, cy, s * 0.5, 8, 0.58, 0)
            d.line(pts + [pts[0]], fill=255, width=w, joint='curve')
            ins = star_outline(cx, cy, s * 0.2, 8, 0.7, math.pi / 8)
            d.line(ins + [ins[0]], fill=255, width=max(1, w - 2), joint='curve')
