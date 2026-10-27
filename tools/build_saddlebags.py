#!/usr/bin/env python3
"""Original wolf saddlebags: mesh (GLB) + Black and Camo textures (0.4.89).

Replaces the Horse Mod's HorseSaddlebags.fbx / HorseSaddlebags_Black.png,
which could not be redistributed (workshop/THIRD_PARTY_ASSETS.md, group
`horsemod`). Nothing here is derived from those files: the geometry and
textures are generated from the numbers below. The only thing kept from
the donor is its FOOTPRINT (measured bounding box, 0.48 m wide x 0.24 m
tall x 0.16 m along the spine, Y up, top edge at y = 0), so the placement
that the playtests tuned in scripts/wtagarou_models.txt (model
WTAGarou_Saddlebags: scale 0.6, attachment rotate 90 0 180) and
WTAGarou.Saddlebag (Definitions) still lands the bag in the same spot on
Bip01_Spine2.

Item space: glTF Y up; X across the wolf, Z along the spine (like the old
harness placeholder). Standard library + numpy only.

    python3 tools/build_saddlebags.py          # writes the GLB and both PNGs
"""
import json, math, os, struct, zlib
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
GLB = os.path.join(ROOT, "common", "media", "models_X", "WTAGarou", "WTAGarou_Saddlebags.glb")
PNG = os.path.join(ROOT, "common", "media", "textures", "WTAGarou", "WTAGarou_Saddlebags.png")
PNG_CAMO = os.path.join(ROOT, "common", "media", "textures", "WTAGarou", "WTAGarou_Saddlebags_Camo.png")

# ---- footprint (metres before the model script's 0.6) -------------------
HALF_W, DEPTH_H, DROP = 0.24, 0.08, 0.24          # x half width, z half depth, hang below y=0
YOKE_T = 0.012                                    # yoke strap thickness
YOKE_SAG = 0.10                                   # the yoke follows the back's curve ...
YOKE_KNEE = 0.13                                  # ... until it reaches the pouches, then lies flat on the lids
POUCH_X0, POUCH_X1 = 0.125, 0.225                 # pouch inner / outer x (mirrored)
POUCH_TOP, POUCH_BOT = -0.055, -DROP
FLAP_X1 = 0.233                                  # the flap is the outermost surface

positions, normals, uvs, indices = [], [], [], []

# UV atlas regions (u0, v0, u1, v1): leather, flap leather, strap, yoke/webbing
UV_LEATHER = (0.02, 0.02, 0.48, 0.48)
UV_FLAP = (0.52, 0.02, 0.98, 0.48)
UV_STRAP = (0.02, 0.54, 0.23, 0.98)
UV_BUCKLE = (0.27, 0.54, 0.48, 0.73)
UV_YOKE = (0.52, 0.54, 0.98, 0.98)


def uvmap(region, u, v):
    u0, v0, u1, v1 = region
    return (u0 + (u1 - u0) * u, v0 + (v1 - v0) * v)


def tri(a, b, c, na, nb, nc, ua, ub, uc):
    base = len(positions)
    positions.extend([a, b, c]); normals.extend([na, nb, nc]); uvs.extend([ua, ub, uc])
    indices.extend([base, base + 1, base + 2])


def quad(a, b, c, d, n, region, flip=False):
    """Flat quad a-b-c-d (counter-clockwise seen from the normal side)."""
    corners = [(a, (0, 0)), (b, (1, 0)), (c, (1, 1)), (d, (0, 1))]
    if flip: corners = [corners[0], corners[3], corners[2], corners[1]]
    base = len(positions)
    for p, uv in corners:
        positions.append(p); normals.append(n); uvs.append(uvmap(region, *uv))
    indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])


def box(x0, x1, y0, y1, z0, z1, region, skip=()):
    faces = {
        "top":    ((x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1), (0, 1, 0)),
        "bottom": ((x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0), (0, -1, 0)),
        "back":   ((x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (0, 0, -1)),
        "front":  ((x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (0, 0, 1)),
        "left":   ((x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (-1, 0, 0)),
        "right":  ((x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (1, 0, 0)),
    }
    for name, (a, b, c, d, n) in faces.items():
        if name not in skip: quad(a, b, c, d, n, region)


def rounded_profile(cx, hx, hz, r, n_corner=5):
    """Rounded rectangle in the XZ plane, centre (cx, 0), half sizes hx/hz, corner radius r.
    Returns points and outward normals, counter-clockwise seen from +Y."""
    pts, nrm = [], []
    for (sx, sz, a0) in ((1, 1, 0.0), (-1, 1, 0.5), (-1, -1, 1.0), (1, -1, 1.5)):
        for i in range(n_corner + 1):
            a = (a0 + 0.5 * i / n_corner) * math.pi
            pts.append((cx + sx * (hx - r) + r * math.cos(a), sz * (hz - r) + r * math.sin(a)))
            nrm.append((math.cos(a), math.sin(a)))
    return pts, nrm


def pouch(side):
    """One hanging pouch: a loft of rounded profiles that bulges toward the bottom."""
    slices = 7
    rings = []
    for k in range(slices + 1):
        t = k / slices                                     # 0 = top, 1 = bottom
        y = POUCH_TOP + (POUCH_BOT - POUCH_TOP) * t
        bulge = math.sin(t * math.pi) * 0.012 + t * 0.006  # fuller lower down
        pinch = 0.008 * (1 - t) ** 2                       # gathered under the flap at the top
        hx = (POUCH_X1 - POUCH_X0) / 2 + 0.5 * bulge - pinch
        hz = DEPTH_H - 0.012 + bulge - pinch
        cx = side * ((POUCH_X0 + POUCH_X1) / 2 - 0.5 * bulge)   # bulge inward: the flap stays outermost
        r = min(0.028, hx * 0.6, hz * 0.6)
        pts, nrm = rounded_profile(cx, hx, hz, r)
        rings.append((y, pts, nrm, t))
    m = len(rings[0][1])
    for k in range(slices):
        ya, pa, na, ta = rings[k]; yb, pb, nb, tb = rings[k + 1]
        for i in range(m):
            j = (i + 1) % m
            a, b = (pa[i][0], ya, pa[i][1]), (pa[j][0], ya, pa[j][1])
            c, d = (pb[j][0], yb, pb[j][1]), (pb[i][0], yb, pb[i][1])
            nai, naj = (na[i][0], 0.08, na[i][1]), (na[j][0], 0.08, na[j][1])
            nbi, nbj = (nb[i][0], -0.1, nb[i][1]), (nb[j][0], -0.1, nb[j][1])
            u0, u1 = i / m, (i + 1) / m
            ua, ub = uvmap(UV_LEATHER, u0, 1 - ta), uvmap(UV_LEATHER, u1, 1 - ta)
            uc, ud = uvmap(UV_LEATHER, u1, 1 - tb), uvmap(UV_LEATHER, u0, 1 - tb)
            # winding: outward = normal side; order so the triangles face out
            tri(a, d, c, nai, nbi, nbj, ua, ud, uc)
            tri(a, c, b, nai, nbj, naj, ua, uc, ub)
    # bottom cap (fan), facing down
    yb, pb, _, _ = rings[-1]
    cxz = (sum(p[0] for p in pb) / m, sum(p[1] for p in pb) / m)
    centre = (cxz[0], yb, cxz[1])
    for i in range(m):
        j = (i + 1) % m
        tri(centre, (pb[j][0], yb, pb[j][1]), (pb[i][0], yb, pb[i][1]), (0, -1, 0), (0, -1, 0), (0, -1, 0),
            uvmap(UV_LEATHER, 0.5, 0.5), uvmap(UV_LEATHER, 0.5 + 0.45 * math.cos(2 * math.pi * j / m), 0.5 + 0.45 * math.sin(2 * math.pi * j / m)),
            uvmap(UV_LEATHER, 0.5 + 0.45 * math.cos(2 * math.pi * i / m), 0.5 + 0.45 * math.sin(2 * math.pi * i / m)))
    # top cap (the flap covers most of it; keep it closed), facing up
    yt, pt, _, _ = rings[0]
    centre = (sum(p[0] for p in pt) / m, yt, sum(p[1] for p in pt) / m)
    for i in range(m):
        j = (i + 1) % m
        tri(centre, (pt[i][0], yt, pt[i][1]), (pt[j][0], yt, pt[j][1]), (0, 1, 0), (0, 1, 0), (0, 1, 0),
            uvmap(UV_LEATHER, 0.5, 0.5), uvmap(UV_LEATHER, 0.5 + 0.45 * math.cos(2 * math.pi * i / m), 0.5 + 0.45 * math.sin(2 * math.pi * i / m)),
            uvmap(UV_LEATHER, 0.5 + 0.45 * math.cos(2 * math.pi * j / m), 0.5 + 0.45 * math.sin(2 * math.pi * j / m)))


def flap(side):
    """Flap: a lid over the pouch top that folds down the OUTER face, two buckle straps on it."""
    x_in, x_out = side * (POUCH_X0 - 0.004), side * FLAP_X1
    xa, xb = (x_in, x_out) if side > 0 else (x_out, x_in)
    # lid
    box(xa, xb, POUCH_TOP + 0.002, POUCH_TOP + 0.014, -DEPTH_H, DEPTH_H, UV_FLAP, skip=("bottom",))
    # fold down the outer face to ~40 % of the drop
    fold_in = side * (POUCH_X1 + 0.002)
    fa, fb = (fold_in, x_out) if side > 0 else (x_out, fold_in)
    box(fa, fb, POUCH_TOP - 0.075, POUCH_TOP + 0.002, -DEPTH_H, DEPTH_H, UV_FLAP, skip=("top",))
    # two straps with buckles, running down the fold and onto the pouch
    for z in (-0.036, 0.036):
        sa, sb = (side * (POUCH_X1 + 0.004), side * (FLAP_X1 + 0.004))
        sa, sb = (sa, sb) if side > 0 else (sb, sa)
        box(sa, sb, POUCH_TOP - 0.135, POUCH_TOP + 0.016, z - 0.011, z + 0.011, UV_STRAP)
        # buckle: a small raised plate at the strap's end
        ba, bb = (side * (FLAP_X1 + 0.004), side * (FLAP_X1 + 0.009))
        ba, bb = (ba, bb) if side > 0 else (bb, ba)
        box(ba, bb, POUCH_TOP - 0.09, POUCH_TOP - 0.06, z - 0.014, z + 0.014, UV_BUCKLE)


def yoke():
    """The strap over the back joining the two pouches; it sags with the back's curve."""
    segs = 16
    def yoke_y(x):
        return -YOKE_SAG * (min(abs(x), YOKE_KNEE) / HALF_W) ** 2
    xs = sorted(set([-FLAP_X1 + 2 * FLAP_X1 * k / segs for k in range(segs + 1)] + [-YOKE_KNEE, YOKE_KNEE]))
    for k in range(len(xs) - 1):
        x0, x1 = xs[k], xs[k + 1]
        y0, y1 = yoke_y(x0), yoke_y(x1)
        z0, z1 = -0.055, 0.055
        # slope normal for the top/bottom faces
        dx, dy = x1 - x0, y1 - y0
        ln = math.hypot(dx, dy); n_top = (-dy / ln, dx / ln, 0.0); n_bot = (dy / ln, -dx / ln, 0.0)
        top = ((x0, y0, z0), (x1, y1, z0), (x1, y1, z1), (x0, y0, z1))
        bot = ((x0, y0 - YOKE_T, z1), (x1, y1 - YOKE_T, z1), (x1, y1 - YOKE_T, z0), (x0, y0 - YOKE_T, z0))
        u0, u1 = (x0 + FLAP_X1) / (2 * FLAP_X1), (x1 + FLAP_X1) / (2 * FLAP_X1)
        for (a, b, c, d), n in ((top, n_top), (bot, n_bot)):
            base = len(positions)
            for p, uv in ((a, (u0, 0)), (b, (u1, 0)), (c, (u1, 1)), (d, (u0, 1))):
                positions.append(p); normals.append(n); uvs.append(uvmap(UV_YOKE, *uv))
            indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
        # front/back edges of the strap
        quad((x0, y0 - YOKE_T, z1), (x1, y1 - YOKE_T, z1), (x1, y1, z1), (x0, y0, z1), (0, 0, 1), UV_STRAP)
        quad((x1, y1 - YOKE_T, z0), (x0, y0 - YOKE_T, z0), (x0, y0, z0), (x1, y1, z0), (0, 0, -1), UV_STRAP)
    # stitched keeper plates where the yoke crosses each flap lid
    for side in (-1, 1):
        xa, xb = sorted((side * (POUCH_X0 + 0.012), side * (POUCH_X1 - 0.012)))
        yk = yoke_y(POUCH_X1)
        box(xa, xb, yk - YOKE_T - 0.002, yk + 0.004, -0.062, 0.062, UV_STRAP)


pouch(1); pouch(-1); flap(1); flap(-1); yoke()

# normalise normals
normals = [tuple(np.array(n) / (np.linalg.norm(n) + 1e-9)) for n in normals]
# glTF front faces are counter-clockwise: make every triangle's winding agree with its
# vertex normals (the quad helpers above are written for readability, not for winding).
_P, _N = np.array(positions), np.array(normals)
for t in range(0, len(indices), 3):
    a, b, c = indices[t:t + 3]
    face = np.cross(_P[b] - _P[a], _P[c] - _P[a])
    if np.dot(face, _N[a] + _N[b] + _N[c]) < 0:
        indices[t + 1], indices[t + 2] = c, b


def pack(fmt, seq):
    return b"".join(struct.pack(fmt, *v) for v in seq)


def pad(b, n=4, ch=b"\x00"):
    return b + ch * ((n - len(b) % n) % n)


pos_bin, nrm_bin, uv_bin = pack("<3f", positions), pack("<3f", normals), pack("<2f", uvs)
idx_bin = pack("<I", [(i,) for i in indices])
bufs = [pad(pos_bin), pad(nrm_bin), pad(uv_bin), pad(idx_bin)]
views, offset = [], 0
for i, b in enumerate(bufs):
    views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(b), "target": 34963 if i == 3 else 34962})
    offset += len(b)
mins = [float(min(p[i] for p in positions)) for i in range(3)]
maxs = [float(max(p[i] for p in positions)) for i in range(3)]
gltf = {
    "asset": {"version": "2.0", "generator": "WTAGarou tools/build_saddlebags.py"},
    "scene": 0, "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "WTAGarou_Saddlebags", "mesh": 0}],
    "meshes": [{"name": "WTAGarou_Saddlebags", "primitives": [{
        "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0, "mode": 4}]}],
    "materials": [{"name": "WTAGarou_Saddlebags", "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 0.9}}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": mins, "max": maxs},
        {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": len(uvs), "type": "VEC2"},
        {"bufferView": 3, "componentType": 5125, "count": len(indices), "type": "SCALAR"},
    ],
    "bufferViews": views, "buffers": [{"byteLength": offset}],
}
json_bin = pad(json.dumps(gltf, separators=(",", ":")).encode(), ch=b" ")
bin_all = b"".join(bufs)
glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(json_bin) + 8 + len(bin_all))
glb += struct.pack("<II", len(json_bin), 0x4E4F534A) + json_bin
glb += struct.pack("<II", len(bin_all), 0x004E4942) + bin_all
os.makedirs(os.path.dirname(GLB), exist_ok=True)
open(GLB, "wb").write(glb)
print("wrote", GLB, len(positions), "vertices", len(indices) // 3, "triangles; bounds", [round(v, 3) for v in mins], [round(v, 3) for v in maxs])


# ---- textures ------------------------------------------------------------
S = 512
rng = np.random.default_rng(2026)
yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)


def fbm(seed, octaves=5, base=8.0):
    r = np.random.default_rng(seed); out = np.zeros((S, S)); amp = 1.0; freq = base
    for _ in range(octaves):
        g = r.normal(0, 1, (int(freq) + 1, int(freq) + 1))
        gx = np.linspace(0, int(freq), S); gy = np.linspace(0, int(freq), S)
        ix = np.clip(gx.astype(int), 0, int(freq) - 1); iy = np.clip(gy.astype(int), 0, int(freq) - 1)
        fx = gx - ix; fy = gy - iy
        a = g[np.ix_(iy, ix)]; b = g[np.ix_(iy, ix + 1)]; c = g[np.ix_(iy + 1, ix)]; d = g[np.ix_(iy + 1, ix + 1)]
        sx = fx[None, :] * fx[None, :] * (3 - 2 * fx[None, :]); sy = fy[:, None] * fy[:, None] * (3 - 2 * fy[:, None])
        out += amp * ((a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy)
        amp *= 0.5; freq *= 2
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def region_mask(region):
    u0, v0, u1, v1 = region
    return (xx >= u0 * S) & (xx < u1 * S) & (yy >= v0 * S) & (yy < v1 * S)


def stitches(region, inset=0.035, pitch=9, width=2.0):
    """Dashed stitch line inset from the region's edges. Returns a 0..1 mask."""
    u0, v0, u1, v1 = region
    x0, x1 = (u0 + inset) * S, (u1 - inset) * S; y0, y1 = (v0 + inset) * S, (v1 - inset) * S
    m = np.zeros((S, S))
    for xline in (x0, x1):
        on = (np.abs(xx - xline) < width) & (yy >= y0) & (yy <= y1) & (((yy // pitch) % 2) == 0); m[on] = 1
    for yline in (y0, y1):
        on = (np.abs(yy - yline) < width) & (xx >= x0) & (xx <= x1) & (((xx // pitch) % 2) == 0); m[on] = 1
    return m


def paint(camo):
    img = np.zeros((S, S, 3))
    grain = fbm(11, 6, 16.0); pores = fbm(12, 3, 96.0); cloud = fbm(13, 4, 4.0)
    if camo:
        blot1, blot2 = fbm(21, 3, 5.0), fbm(22, 3, 7.0)
        base = np.where(blot1[..., None] > 0.58, np.array([62, 58, 34]), np.where(blot2[..., None] > 0.55, np.array([38, 46, 30]), np.array([84, 74, 46])))
        base = base * (0.85 + 0.3 * grain[..., None])
    else:
        base = np.stack([46 * (0.7 + 0.6 * grain) + 10 * cloud, 30 * (0.7 + 0.6 * grain) + 6 * cloud,
                         20 * (0.7 + 0.6 * grain) + 4 * cloud], -1)
    base = base - 14 * (pores[..., None] > 0.62)                         # pore speckle
    img[:] = base
    # flap leather: a shade lighter and more worn
    m = region_mask(UV_FLAP); img[m] = img[m] * 1.18 + 8
    # straps and yoke: darker oiled webbing with a weave
    weave = (((xx // 3) % 2 == 0) ^ ((yy // 3) % 2 == 0)) * 10.0
    for reg in (UV_STRAP, UV_YOKE):
        m = region_mask(reg); img[m] = (np.array([34, 24, 16]) * (0.8 + 0.4 * grain[..., None]))[m] + weave[m][:, None]
        if camo:
            img[m] = (np.array([40, 44, 30]) * (0.8 + 0.4 * grain[..., None]))[m] + weave[m][:, None]
    # buckle: brushed brass plate with a dark slot
    m = region_mask(UV_BUCKLE)
    brush = 1 + 0.12 * np.sin(yy * 1.7) * grain
    img[m] = (np.array([168, 134, 70]) * brush[..., None])[m]
    u0, v0, u1, v1 = UV_BUCKLE
    slot = m & (np.abs(yy - (v0 + v1) / 2 * S) < 6) & (xx > (u0 + 0.25 * (u1 - u0)) * S) & (xx < (u1 - 0.25 * (u1 - u0)) * S)
    img[slot] = np.array([40, 30, 14])
    # stitching along leather and strap edges
    thread = np.array([176, 150, 96])
    for reg, inset in ((UV_LEATHER, 0.03), (UV_FLAP, 0.03), (UV_YOKE, 0.02), (UV_STRAP, 0.04)):
        st = stitches(reg, inset); img[st > 0] = img[st > 0] * 0.3 + thread * 0.7
    # edge darkening on the leather panels (worn, folded edges)
    for reg in (UV_LEATHER, UV_FLAP):
        u0, v0, u1, v1 = reg
        du = np.minimum(xx - u0 * S, u1 * S - xx); dv = np.minimum(yy - v0 * S, v1 * S - yy)
        edge = np.clip(1 - np.minimum(du, dv) / 14.0, 0, 1) * region_mask(reg)
        img = img * (1 - 0.35 * edge[..., None])
    # scuffs
    scuff = fbm(31, 2, 40.0) > 0.78
    img[scuff] = img[scuff] * 1.15 + 6
    return np.clip(img, 0, 255).astype(np.uint8)


def write_png(path, rgb):
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(rgb.shape[0]))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", rgb.shape[1], rgb.shape[0], 8, 2, 0, 0, 0)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    print("wrote", path)


write_png(PNG, paint(camo=False))
write_png(PNG_CAMO, paint(camo=True))
