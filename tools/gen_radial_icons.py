import numpy as np, math
from PIL import Image, ImageDraw, ImageFilter

OUT = 48; SS = 8; S = OUT*SS
C = S/2; R = 0.40*S

yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
X = xx + 0.5 - C; Y = yy + 0.5 - C
disc = (X**2 + Y**2) <= R**2

def lit_mask(k):
    if k is None: return disc.copy()
    if k == 0: return disc & (X >= 0)
    a = abs(k)*R
    e = (X/a)**2 + (Y/R)**2 <= 1.0
    if k > 0: return disc & ((X >= 0) | e)
    return disc & (X >= 0) & ~e

def paw_mask(cx, cy, s, rot_deg=-18):
    """Wolf paw print: one big pad + four toes; returns bool mask."""
    m = np.zeros((S, S), bool)
    th = math.radians(rot_deg)
    def ell(ox, oy, rx, ry):
        # rotate local offsets
        lx = ox*math.cos(th) - oy*math.sin(th); ly = ox*math.sin(th) + oy*math.cos(th)
        # rotate coordinates into ellipse frame
        dx = X - (cx + lx*s); dy = Y - (cy + ly*s)
        ux = dx*math.cos(-th) - dy*math.sin(-th); uy = dx*math.sin(-th) + dy*math.cos(-th)
        return (ux/(rx*s))**2 + (uy/(ry*s))**2 <= 1.0
    m |= ell(0, 0.30, 0.44, 0.34)          # main pad
    for ox, oy in ((-0.52, -0.16), (-0.19, -0.44), (0.19, -0.44), (0.52, -0.16)):
        m |= ell(ox, oy, 0.17, 0.22)       # toes
    return m

def to_img(rgb_layers):
    """rgb_layers: list of (mask(float 0..1), (r,g,b)) painted in order."""
    img = np.zeros((S, S, 4), np.float64)
    for a, col in rgb_layers:
        a = np.clip(a, 0, 1)[..., None]
        src = np.concatenate([np.full((S, S, 3), np.array(col)/255.0), np.ones((S, S, 1))], 2)
        img[..., :3] = src[..., :3]*a + img[..., :3]*(1-a)
        img[..., 3:] = a + img[..., 3:]*(1-a)
    out = Image.fromarray((img*255).round().astype(np.uint8), "RGBA")
    return out.resize((OUT, OUT), Image.LANCZOS)

def outline(mask, px=1.1):
    """Soft dark edge just outside a mask."""
    im = Image.fromarray((mask*255).astype(np.uint8))
    grown = im.filter(ImageFilter.MaxFilter(int(px*SS)*2+1))
    return (np.asarray(grown, np.float64)/255.0) - mask.astype(np.float64)

DARK = (34, 34, 40)
SHADOW = (58, 58, 68)

def moon(name, k, col, paw_center, paw_size, paw_alpha=0.30):
    lit = lit_mask(k)
    layers = []
    # unlit face of the moon (so the phase reads as a moon)
    layers.append((disc.astype(float)*0.42 if k is not None else np.zeros((S,S)), SHADOW))
    layers.append((outline(lit, 1.0)*0.55, DARK))
    layers.append((lit.astype(float), col))
    # paw craters: slightly darker version of the lit colour, only on the lit face
    paw = paw_mask(*paw_center, paw_size) & lit
    crater = tuple(int(c*0.60) for c in col)
    layers.append((paw.astype(float)*paw_alpha, crater))
    # a hint of a rim highlight on the lit edge: none, keep it clean
    to_img(layers).save(f"wta_{name}.png")

def new_moon(name, col):
    ring = disc & ~((X**2 + Y**2) <= (R-0.075*S)**2)
    inner = disc & ~ring
    layers = []
    layers.append((inner.astype(float)*0.32, SHADOW))
    layers.append((outline(ring, 1.0)*0.55, DARK))
    layers.append((ring.astype(float), col))
    paw = paw_mask(0.02*S, 0.02*S, 0.24*S) & inner
    layers.append((paw.astype(float)*0.45, col))
    to_img(layers).save(f"wta_{name}.png")

WHITE = (242, 242, 247); AMBER = (232, 162, 50); BLOOD = (186, 38, 46)
new_moon("homid", WHITE)
moon("glabro", -0.62, AMBER, (0.325*S, 0.02*S), 0.085*S, 0.85)     # waxing crescent
moon("crinos", 0,     BLOOD, (0.20*S, 0.02*S), 0.15*S, 0.80)      # half moon
moon("hispo",  0.62,  AMBER, (0.10*S, 0.02*S), 0.20*S, 0.70)      # waxing gibbous
moon("lupus",  None,  WHITE, (0.03*S, 0.03*S), 0.23*S, 0.55)      # full moon

# Strip: crossed-out T-shirt
def shirt():
    im = Image.new("L", (S, S), 0); d = ImageDraw.Draw(im)
    u = S/48.0
    body = [(14*u, 12*u), (19*u, 8*u), (22*u, 11*u), (26*u, 11*u), (29*u, 8*u), (34*u, 12*u),
            (40*u, 18*u), (35*u, 22*u), (33*u, 20*u), (33*u, 40*u), (15*u, 40*u), (15*u, 20*u),
            (13*u, 22*u), (8*u, 18*u)]
    d.polygon(body, fill=255)
    return np.asarray(im, np.float64)/255.0
sh = shirt()
def slash():
    im = Image.new("L", (S, S), 0); d = ImageDraw.Draw(im)
    u = S/48.0
    d.line([(9*u, 41*u), (39*u, 7*u)], fill=255, width=int(5.2*u))
    d.ellipse([(9-2.6)*u, (41-2.6)*u, (9+2.6)*u, (41+2.6)*u], fill=255)
    d.ellipse([(39-2.6)*u, (7-2.6)*u, (39+2.6)*u, (7+2.6)*u], fill=255)
    return np.asarray(im, np.float64)/255.0
sl = slash()
layers = [(outline(sh > 0.5, 1.0)*0.6, DARK), (sh, (214, 214, 222)),
          (outline(sl > 0.5, 1.0)*0.7, DARK), (sl, (204, 44, 48))]
to_img(layers).save("wta_strip.png")

# Dress: the same T-shirt with a green check mark (counter-command to Strip)
def check_mark():
    im = Image.new("L", (S, S), 0); d = ImageDraw.Draw(im)
    u = S/48.0
    pts = [(24*u, 32*u), (31*u, 39*u), (44*u, 22*u)]
    d.line(pts, fill=255, width=int(5.4*u), joint="curve")
    for x, y in pts:
        d.ellipse([(x-2.7*u), (y-2.7*u), (x+2.7*u), (y+2.7*u)], fill=255)
    return np.asarray(im, np.float64)/255.0
ck = check_mark()
layers = [(outline(sh > 0.5, 1.0)*0.6, DARK), (sh, (214, 214, 222)),
          (outline(ck > 0.5, 1.0)*0.7, DARK), (ck, (70, 190, 90))]
to_img(layers).save("wta_dress.png")

# contact sheet on a radial-like dark background
names = ["homid", "glabro", "crinos", "hispo", "lupus", "strip", "dress"]
sheet = Image.new("RGBA", (len(names)*112+8, 240), (40, 40, 40, 255))
for i, n in enumerate(names):
    im = Image.open(f"wta_{n}.png").convert("RGBA")
    sheet.alpha_composite(im.resize((96, 96), Image.NEAREST), (8+i*112, 12))
    sheet.alpha_composite(im, (8+i*112+24, 130))
sheet.save("sheet.png")
