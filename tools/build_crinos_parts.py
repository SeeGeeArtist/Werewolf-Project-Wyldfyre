#!/usr/bin/env python3
"""Original Crinos digitigrade legs and tail: skinned GLBs + coat textures (0.4.90).

Replaces RabenRabo's leg and tail meshes (and the tail textures baked from
his dye sheet) with geometry and textures generated here from scratch. The
meshes are lofted along splines, skinned to the vanilla Bip01 rig
(tools/data/bip01_bind_pose.json holds the measured bind pose of the game's
own skeleton) and UV-mapped onto their own textures, so nothing depends on
the donor files, the donor UV layout or the donor body-part masks.

Outputs (0.4.94: unisex, one file per part; the shipped files are the
author's Blender models, so this tool REFUSES to overwrite a GLB it did
not generate unless --force is given; it writes <name>.base.glb instead)
  common/media/models_X/Skinned/Clothes/WTAGarou_CrinosLegs.glb
  common/media/models_X/Skinned/Clothes/WTAGarou_CrinosTail.glb
  (textures: none - legs use the coat's CrinosBody sheet, the tail the Wolf sheet)

The legs are UV-mapped on the VANILLA human body atlas (leg and foot
islands), so they take the coat's CrinosBody_<Coat> sheet that the author
paints - including his claw dot on the foot island (0.4.91). The tail has
its own sheet; its palette is sampled from the same CrinosBody sheet. Space: metres of the vanilla rig
(a character is ~1 unit tall), Y up, +Z forward, +X = character's left.

    python3 tools/build_crinos_parts.py            # everything
    python3 tools/build_crinos_parts.py --no-tex   # meshes only
"""
import json, math, os, struct, sys, zlib
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
CLOTHES = os.path.join(ROOT, "common", "media", "models_X", "Skinned", "Clothes")
BODY = os.path.join(ROOT, "common", "media", "textures", "Body")
RIG = json.load(open(os.path.join(HERE, "data", "bip01_bind_pose.json")))
COATS = ("Timber", "Brown", "Blonde", "Brindle", "White", "Black")

# ---------------------------------------------------------------- rig ----
WORLD = {k: np.array(v, dtype=np.float64) for k, v in RIG["world"].items()}   # FBX row-major
PARENTS = RIG["parents"]


def world_matrix_col(name):
    """Column-major 4x4 world bind matrix (glTF convention) of a bone, or identity for Bip01."""
    if name == "Bip01":
        return np.eye(4)
    return WORLD[name].T.copy()


def joint_order(used):
    """All ancestors of the used bones, parents before children."""
    order = []
    def add(n):
        if n in order or n == "Bip01": return
        add(PARENTS[n]); order.append(n)
    for n in used: add(n)
    return order


# ------------------------------------------------------------- mesh -------
class Mesh:
    def __init__(self):
        self.P, self.N, self.UV, self.J, self.W, self.I = [], [], [], [], [], []

    def vertex(self, p, n, uv, weights):
        """weights: {bone: w}; keeps the four largest, normalised."""
        items = sorted(weights.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(w for _, w in items) or 1.0
        j = [b for b, _ in items] + [None] * (4 - len(items))
        w = [wt / tot for _, wt in items] + [0.0] * (4 - len(items))
        self.P.append(tuple(map(float, p))); self.N.append(tuple(map(float, n))); self.UV.append(tuple(map(float, uv)))
        self.J.append(j); self.W.append(w)
        return len(self.P) - 1

    def tri(self, a, b, c):
        self.I.extend([a, b, c])

    def fix_winding(self):
        P, N = np.array(self.P), np.array(self.N)
        for t in range(0, len(self.I), 3):
            a, b, c = self.I[t:t + 3]
            if np.dot(np.cross(P[b] - P[a], P[c] - P[a]), N[a] + N[b] + N[c]) < 0:
                self.I[t + 1], self.I[t + 2] = c, b

    def mirror_x(self, rename):
        """Return a copy mirrored across x=0 with bones renamed (L <-> R)."""
        m = Mesh()
        m.P = [(-x, y, z) for x, y, z in self.P]; m.N = [(-x, y, z) for x, y, z in self.N]
        m.UV = list(self.UV); m.W = [list(w) for w in self.W]
        m.J = [[rename.get(b, b) if b else None for b in j] for j in self.J]
        m.I = list(self.I); m.fix_winding()
        return m

    def extend(self, other):
        base = len(self.P)
        self.P += other.P; self.N += other.N; self.UV += other.UV; self.J += other.J; self.W += other.W
        self.I += [i + base for i in other.I]


def catmull_rom(points, n, ts=None):
    """Catmull-Rom through the points; returns samples and tangents at n uniform
    parameters, or at the explicit 0..1 parameters in ts (ring placement)."""
    pts = np.array(points, dtype=np.float64)
    ext = np.vstack([pts[0] + (pts[0] - pts[1]), pts, pts[-1] + (pts[-1] - pts[-2])])
    segs = len(pts) - 1
    out, tan = [], []
    params = list(ts) if ts is not None else [k / (n - 1) for k in range(n)]
    for tp in params:
        s = min(max(tp, 0.0), 1.0) * segs
        i = min(int(s), segs - 1); t = s - i
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        a = 2 * p1; b = p2 - p0; c = 2 * p0 - 5 * p1 + 4 * p2 - p3; d = -p0 + 3 * p1 - 3 * p2 + p3
        out.append(0.5 * (a + b * t + c * t * t + d * t ** 3))
        tan.append(0.5 * (b + 2 * c * t + 3 * d * t * t))
    return np.array(out), np.array(tan)


def loft(mesh, points, radius_fn, weight_fn, uv_fn, rings=24, around=16, side_hint=(1, 0, 0),
         cap_start=False, cap_end=True, squash_fn=None, bump_fn=None, ts=None):
    """Tube along a spline. radius_fn(t) -> (r_side, r_other); weight_fn(t) -> {bone: w};
    uv_fn(t, a) -> (u, v). squash_fn(t) -> extra vertical offset of the ring centre.
    bump_fn(t, angle) -> radial multiplier (fur silhouette). ts: explicit ring
    parameters (0..1) for low-poly placement at landmarks. Returns ring vertex ids."""
    if ts is not None: rings = len(ts)
    C, T = catmull_rom(points, rings, ts)
    tvals = list(ts) if ts is not None else [k / (rings - 1) for k in range(rings)]
    hint = np.array(side_hint, dtype=np.float64)
    ids = []
    for k in range(rings):
        t = tvals[k]
        tg = T[k] / (np.linalg.norm(T[k]) + 1e-12)
        side = hint - np.dot(hint, tg) * tg
        if np.linalg.norm(side) < 1e-6:
            side = np.cross(tg, (0, 0, 1.0))
        side /= np.linalg.norm(side)
        other = np.cross(tg, side)
        rs, ro = radius_fn(t)
        centre = C[k] + (np.array(squash_fn(t)) if squash_fn else 0)
        ring = []
        for i in range(around):
            a = 2 * math.pi * i / around
            mul = bump_fn(t, a) if bump_fn else 1.0
            dirv = math.cos(a) * side * rs + math.sin(a) * other * ro
            p = centre + dirv * mul
            n = math.cos(a) * side / max(rs, 1e-6) + math.sin(a) * other / max(ro, 1e-6)
            n /= np.linalg.norm(n)
            ring.append(mesh.vertex(p, n, uv_fn(t, i / around), weight_fn(t)))
        # seam duplicate so the UV wraps cleanly
        a = 2 * math.pi; mul = bump_fn(t, 0.0) if bump_fn else 1.0
        p = centre + (side * rs) * mul; n = side / max(rs, 1e-6); n /= np.linalg.norm(n)
        ring.append(mesh.vertex(p, n, uv_fn(t, 1.0), weight_fn(t)))
        ids.append(ring)
    for k in range(rings - 1):
        for i in range(around):
            a, b = ids[k][i], ids[k][i + 1]; c, d = ids[k + 1][i + 1], ids[k + 1][i]
            mesh.tri(a, b, c); mesh.tri(a, c, d)
    for cap, k, sign in ((cap_start, 0, -1), (cap_end, rings - 1, 1)):
        if not cap: continue
        tg = T[k] / np.linalg.norm(T[k]) * sign
        centre_p = np.mean([mesh.P[v] for v in ids[k][:around]], axis=0)
        cidx = mesh.vertex(centre_p, tg, uv_fn(tvals[k], 0.5), weight_fn(tvals[k]))
        for i in range(around):
            mesh.tri(cidx, ids[k][i], ids[k][i + 1])
    return ids


def blend(t, a, b, t0, t1):
    """Weights: bone a before t0, bone b after t1, linear between."""
    if t <= t0: return {a: 1.0}
    if t >= t1: return {b: 1.0}
    s = (t - t0) / (t1 - t0)
    return {a: 1 - s, b: s}


# --------------------------------------------------------- UV atlas -------
# LEGS: mapped on the VANILLA human body atlas (the coat's CrinosBody_<Coat>
# sheet, 256 px, which the author paints), 0.4.91. Island rectangles are the
# game's UV template, read off the body-part masks: left leg x 128-205 /
# y 163-256, right leg mirrored about x = 128; left foot strip x 150-172 /
# y 0-80 (toe blob at the bottom), right foot mirrored. The author's claw
# dot sits at (161.5, 72.5) on the left foot (94.5 on the right).
LEG_ISLAND = (129 / 256, 164 / 256, 204 / 256, 254 / 256)    # left leg: u0, v0, u1, v1
FOOT_STRIP = (151 / 256, 6 / 256, 171 / 256, 62 / 256)       # left foot: metatarsus down the strip
FOOT_PAW = (149 / 256, 60 / 256, 175 / 256, 70 / 256)        # top of the paw, just above the toes
FOOT_TOES = (152 / 256, 60 / 256, 171 / 256, 69 / 256)       # toes: fur just above the claw dot (never on it)
CLAW_DOT = (161.5 / 256, 72.5 / 256)                         # the author's dark dot
FOOT_PADS = (150 / 256, 74 / 256, 174 / 256, 80 / 256)
UV_TAIL = (0.02, 0.02, 0.98, 0.98)        # whole tail sheet: u around, v base -> tip


def region(r, u, v):
    u0, v0, u1, v1 = r
    return (u0 + (u1 - u0) * u, v0 + (v1 - v0) * v)


def gauss(x, sigma):
    return math.exp(-0.5 * (x / sigma) ** 2)


def ang_diff(a, b):
    d = (a - b + math.pi) % (2 * math.pi) - math.pi
    return d


def recompute_normals(mesh, keep_below_y=None):
    """Smooth normals accumulated over faces, merging vertices by position (so UV
    seams stay smooth). keep_below_y: leave flat normals on vertices under it (pads)."""
    P = np.array(mesh.P); acc = {}
    def key(p): return (round(p[0], 5), round(p[1], 5), round(p[2], 5))
    for t in range(0, len(mesh.I), 3):
        a, b, c = mesh.I[t:t + 3]
        n = np.cross(P[b] - P[a], P[c] - P[a])
        for v in (a, b, c):
            k = key(P[v]); acc[k] = acc.get(k, 0) + n
    for v in range(len(P)):
        if keep_below_y is not None and P[v][1] < keep_below_y: continue
        n = acc.get(key(P[v]))
        if n is not None and np.linalg.norm(n) > 1e-12:
            mesh.N[v] = tuple(n / np.linalg.norm(n))


def unweld(mesh):
    """Flat-shaded copy: every triangle gets its own three vertices carrying the
    face normal (the faceted look of the vanilla low-poly body)."""
    out = Mesh(); P = np.array(mesh.P)
    for t in range(0, len(mesh.I), 3):
        a, b, c = mesh.I[t:t + 3]
        n = np.cross(P[b] - P[a], P[c] - P[a]); ln = np.linalg.norm(n)
        if ln < 1e-14: continue
        n = tuple(n / ln)
        ids = [out.vertex(mesh.P[v], n, mesh.UV[v], {j: w for j, w in zip(mesh.J[v], mesh.W[v]) if j}) for v in (a, b, c)]
        out.tri(*ids)
    return out


# -------------------------------------------------------------- leg -------
HOCK_T = 0.66      # spline parameter of the hock: leg island above, foot strip below
# Low-poly ring placement (0.4.92): 8 sides, rings only at anatomical landmarks,
# flat shading. Polycount target is the vanilla body's density (the author's
# reference export of the previous legs measured 352 triangles for both legs).
LEG_RING_TS = [0.0, 0.07, 0.15, 0.24, 0.33, 0.40, 0.47, 0.55, 0.62, HOCK_T, 0.72, 0.80, 0.90, 1.0]


def build_leg(female):
    """Left digitigrade leg; mirrored (with mirrored UVs) for the right."""
    L, R = "Bip01_L_", "Bip01_R_"
    s = 0.92 if female else 1.0                     # slimmer female leg
    # Centreline: hip -> knee (forward) -> hock (back, raised) -> pastern -> paw root.
    # Thigh top follows the vanilla stump the author matched (centre x 0.059,
    # z -0.025; deeper than wide) and starts just under the hip joint.
    # Zig-zag toned down in 0.4.92 (knee front about +0.05, hock back about
    # -0.10, the envelope the author's reference measured): reads digitigrade
    # without the stilt look.
    pts = [
        (0.060, 0.497, -0.024),   # hip top
        (0.063, 0.440, -0.016),   # upper thigh
        (0.070, 0.360, -0.002),   # lower thigh
        (0.076, 0.305, 0.014),    # knee, a little forward
        (0.084, 0.240, -0.006),   # upper shank
        (0.095, 0.175, -0.046),   # lower shank
        (0.102, 0.135, -0.068),   # hock
        (0.104, 0.080, -0.052),   # metatarsus
        (0.105, 0.040, -0.026),   # pastern
        (0.106, 0.026, -0.008),   # paw root
        # 0.4.93: the paw body is part of the same loft (no stitched wedge at the
        # pastern). Points 10 and 11 run the paw forward to the knuckle line;
        # the anatomy functions below are written in the 10-point parameter.
        (0.106, 0.021, 0.010),    # paw body
        (0.106, 0.019, 0.026),    # knuckle line
    ]
    PAW_T0 = 9 / 11               # spline parameter of the paw root in the 12-point spline
    def leg_t(t): return min(t / PAW_T0, 1.0)   # 12-point parameter -> 10-point parameter
    prof = [(0.054, 0.064), (0.056, 0.066), (0.050, 0.060), (0.044, 0.050), (0.036, 0.046),
            (0.028, 0.034), (0.024, 0.032), (0.021, 0.026), (0.022, 0.026), (0.028, 0.024),
            (0.034, 0.019), (0.040, 0.017)]
    def radius(t):
        f = t * (len(prof) - 1); i = min(int(f), len(prof) - 2); u = f - i
        a, b = prof[i], prof[i + 1]
        return ((a[0] * (1 - u) + b[0] * u) * s, (a[1] * (1 - u) + b[1] * u) * s)
    FRONT, BACK, OUTER, INNER = math.pi / 2, 3 * math.pi / 2, 0.0, math.pi
    def shape(t, a):
        """Anatomy on top of the ellipse: quads, hamstring, knee cap, calf, hock point,
        tendon ridge and fur feathering. Multiplies the radius."""
        if t >= PAW_T0: return 1.0
        t = leg_t(t)
        m = 1.0
        m += 0.12 * gauss(ang_diff(a, FRONT - 0.5), 0.9) * gauss(t - 0.22, 0.10)     # quadriceps, front-outer
        m += 0.08 * gauss(ang_diff(a, BACK), 0.8) * gauss(t - 0.15, 0.07)            # hamstring (stops above the knee)
        m -= 0.07 * gauss(ang_diff(a, BACK), 0.6) * gauss(t - 0.34, 0.045)           # popliteal fossa, hollow behind the knee
        m += 0.10 * gauss(ang_diff(a, FRONT), 0.6) * gauss(t - 0.33, 0.03)           # knee cap
        m -= 0.04 * gauss(ang_diff(a, FRONT), 0.6) * gauss(t - 0.44, 0.05)           # straight shin front under the cap
        m += 0.16 * gauss(ang_diff(a, BACK), 0.9) * gauss(t - 0.46, 0.06)            # calf
        m += 0.22 * gauss(ang_diff(a, BACK), 0.7) * gauss(t - HOCK_T, 0.04)          # hock point
        m += 0.06 * gauss(ang_diff(a, BACK), 0.45) * gauss(t - 0.58, 0.05)           # tendon ridge
        m += 0.12 * gauss(ang_diff(a, BACK), 0.8) * gauss(t - 0.76, 0.08)            # fur tuft behind the hock
        m += 0.08 * gauss(ang_diff(a, BACK + 0.3), 0.7) * gauss(t - 0.13, 0.09)      # feathering down the back of the thigh
        m -= 0.05 * gauss(ang_diff(a, INNER), 0.6) * gauss(t - 0.40, 0.08)           # hollow inside the knee
        return m
    def weights(t):
        if t >= PAW_T0:
            u = (t - PAW_T0) / (1 - PAW_T0)
            return {L + "Foot": 1.0 - 0.45 * u, L + "Toe0": 0.45 * u} if u > 0 else {L + "Foot": 1.0}
        t = leg_t(t)
        if t < 0.05: return {"Bip01_Pelvis": 0.35, L + "Thigh": 0.65}
        if t < 0.28: return {L + "Thigh": 1.0}
        if t < 0.40: return blend(t, L + "Thigh", L + "Calf", 0.28, 0.40)
        if t < 0.60: return {L + "Calf": 1.0}
        if t < 0.72: return blend(t, L + "Calf", L + "Foot", 0.60, 0.72)
        return {L + "Foot": 1.0}
    def uv(t, a):
        # a in 0..1 around (0 = outer side). Seam at the outer side; v down the island.
        if t >= PAW_T0:
            return region(FOOT_PAW, a, (t - PAW_T0) / (1 - PAW_T0))
        t = leg_t(t)
        if t <= HOCK_T:
            return region(LEG_ISLAND, a, t / HOCK_T)
        return region(FOOT_STRIP, a, (t - HOCK_T) / (1 - HOCK_T))
    leg = Mesh()
    ts = [t * PAW_T0 for t in LEG_RING_TS] + [10 / 11, 1.0]
    rings = loft(leg, pts, radius, weights, uv, around=8, side_hint=(1, 0, 0),
                 cap_start=True, cap_end=True, bump_fn=shape, ts=ts)
    # ---- paw (0.4.93): a tall rounded paw body from the paw root forward to the
    # knuckle line, then four knuckled, asymmetric toes (digits III/IV longest and
    # set forward, II/V shorter and set back), each a 3-ring tube that rises to
    # the knuckle and slopes to the ground. The claw is a short wedge that
    # continues the toe tip, mostly hidden by fur, not a talon.
    x0 = pts[-1][0]
    # toes: (x offset, base z, length, splay). Inner digit II is at -x on the left paw.
    TOES = ((-0.024, 0.016, 0.025, -0.14), (-0.008, 0.022, 0.031, -0.04),
            (0.008, 0.022, 0.031, 0.04), (0.024, 0.014, 0.023, 0.14))
    pad_spots = []
    for k, (off, bz, length, splay) in enumerate(TOES):
        tx = x0 + off * s
        dx, dz = math.sin(splay) * length, math.cos(splay) * length
        # base inside the paw body, knuckle raised above it, tip on the ground
        toe_pts = [(tx, 0.021, bz), (tx + dx * 0.42, 0.030, bz + dz * 0.42), (tx + dx, 0.0085, bz + dz)]
        toe_r = [(0.0110, 0.0100), (0.0118, 0.0110), (0.0085, 0.0078)]
        def toe_radius(t, toe_r=toe_r):
            f = t * 2; i = min(int(f), 1); u = f - i
            return ((toe_r[i][0] * (1 - u) + toe_r[i + 1][0] * u) * s, (toe_r[i][1] * (1 - u) + toe_r[i + 1][1] * u) * s)
        toe = Mesh()
        loft(toe, toe_pts, toe_radius, lambda t: {L + "Toe0": 0.8, L + "Foot": 0.2},
             lambda t, a, k=k: region(FOOT_TOES, 0.15 + 0.7 * ((k + a) / 4.0), 0.1 + 0.6 * t),
             rings=3, around=6, side_hint=(1, 0, 0), cap_start=True, cap_end=True)
        leg.extend(toe)
        tip = np.array(toe_pts[-1]); fwd = np.array((math.sin(splay), 0.0, math.cos(splay)))
        # claw: a low ridge that emerges from the fur at the toe tip and runs
        # ~7 mm forward and down to the ground; wider than tall, no talon
        claw_pts = [tuple(tip + fwd * -0.001 + (0, -0.002, 0)), tuple(tip + fwd * 0.004 + (0, -0.005, 0)),
                    tuple(tip + fwd * 0.0075 + (0, -0.0075, 0))]
        claw = Mesh()
        loft(claw, claw_pts, lambda t: (0.0048 * (1 - 0.7 * t), 0.0032 * (1 - 0.75 * t)),
             lambda t: {L + "Toe0": 1.0},
             lambda t, a: (CLAW_DOT[0] + (a - 0.5) * 0.004, CLAW_DOT[1] + (t - 0.5) * 0.004),
             rings=3, around=4, side_hint=(1, 0, 0), cap_start=True, cap_end=True)
        leg.extend(claw)
        pad_spots.append((tx + dx * 0.72, bz + dz * 0.72, 0.0065 * s, 0.006))
    # ---- pads underneath: metacarpal pad under the paw body, one under each toe
    for (px, pz, prx, prz) in [(x0, 0.012, 0.021 * s, 0.013)] + pad_spots:
        w = {L + "Foot": 0.6, L + "Toe0": 0.4}
        c = leg.vertex((px, 0.002, pz), (0, -1, 0), region(FOOT_PADS, 0.5, 0.5), w)
        ring = [leg.vertex((px + prx * math.cos(2 * math.pi * i / 6), 0.002, pz + prz * math.sin(2 * math.pi * i / 6)), (0, -1, 0),
                           region(FOOT_PADS, 0.5 + 0.45 * math.cos(2 * math.pi * i / 6), 0.5 + 0.45 * math.sin(2 * math.pi * i / 6)), w) for i in range(6)]
        for i in range(6): leg.tri(c, ring[(i + 1) % 6], ring[i])
    leg.fix_winding()
    leg = unweld(leg)                      # faceted, like the vanilla body
    right = leg.mirror_x({L + b: R + b for b in ("Thigh", "Calf", "Foot", "Toe0")})
    right.UV = [(1.0 - u, v) for (u, v) in right.UV]       # the atlas is symmetric about u = 0.5
    both = Mesh(); both.extend(leg); both.extend(right)
    return both


# ------------------------------------------------------------- tail -------
def build_tail():
    """Bushy tail from the sacrum, curving down and back. Pelvis-driven with a little
    Spine1 at the root (the author's weighting choice for the previous tail)."""
    pel = WORLD["Bip01_Pelvis"][3, :3]
    pts = [(0.0, 0.548, -0.055), (0.0, 0.520, -0.095), (0.0, 0.470, -0.130), (0.0, 0.420, -0.147), (0.0, 0.378, -0.150)]
    def radius(t):
        r = 0.030 * (1 - t) + 0.034 * math.sin(math.pi * min(1, t * 1.25)) ** 0.8 * 0.55 + 0.012 * t
        if t > 0.9: r *= 1 - (t - 0.9) / 0.1 * 0.8
        return (r, r)
    def weights(t):
        return {"Bip01_Pelvis": 1.0 - 0.25 * (1 - t), "Bip01_Spine1": 0.25 * (1 - t)}
    def bump(t, a):
        return 1.0 + 0.08 * math.sin(3 * a + 7 * t) * math.sin(math.pi * t) + 0.05 * math.cos(5 * a - 9 * t)
    tail = Mesh()
    loft(tail, pts, radius, weights, lambda t, a: region(UV_TAIL, a, t), rings=22, around=16,
         side_hint=(1, 0, 0), cap_start=True, cap_end=True, bump_fn=bump)
    recompute_normals(tail)
    tail.fix_winding()
    return tail


# -------------------------------------------------------------- GLB -------
def write_glb(path, mesh, name):
    used = sorted({b for j in mesh.J for b in j if b})
    joints = joint_order(used)
    node_index = {"Bip01": 0}
    nodes = [{"name": "Bip01", "children": []}]
    for b in joints:
        node_index[b] = len(nodes)
        parent = PARENTS[b]
        local = np.linalg.inv(world_matrix_col(parent)) @ world_matrix_col(b)
        nodes.append({"name": b, "matrix": [float(v) for v in local.T.flatten()]})   # glTF: column-major flatten
        nodes[node_index[parent]].setdefault("children", []).append(node_index[b])
    mesh_node = len(nodes)
    nodes.append({"name": name, "mesh": 0, "skin": 0})
    jidx = {b: i for i, b in enumerate(joints)}
    ibm = np.array([np.linalg.inv(world_matrix_col(b)).T.flatten() for b in joints], dtype=np.float32)

    def pack(fmt, rows): return b"".join(struct.pack(fmt, *r) for r in rows)
    def pad(b, n=4, ch=b"\x00"): return b + ch * ((n - len(b) % n) % n)
    pos = pack("<3f", mesh.P); nrm = pack("<3f", mesh.N); uv = pack("<2f", mesh.UV)
    jnt = pack("<4B", [[jidx[b] if b else 0 for b in j] for j in mesh.J]); wgt = pack("<4f", mesh.W)
    idx = pack("<I", [(i,) for i in mesh.I]); ibmb = ibm.tobytes()
    bufs = [pad(pos), pad(nrm), pad(uv), pad(jnt), pad(wgt), pad(idx), pad(ibmb)]
    views, off = [], 0
    for i, b in enumerate(bufs):
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(b)}
        if i < 5: v["target"] = 34962
        if i == 5: v["target"] = 34963
        views.append(v); off += len(b)
    P = np.array(mesh.P)
    gltf = {
        "asset": {"version": "2.0", "generator": "WTAGarou tools/build_crinos_parts.py"},
        "scene": 0, "scenes": [{"nodes": [0, mesh_node]}], "nodes": nodes,
        "meshes": [{"name": name, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2, "JOINTS_0": 3, "WEIGHTS_0": 4},
                                                   "indices": 5, "material": 0, "mode": 4}]}],
        "skins": [{"name": name + "_Skin", "inverseBindMatrices": 6, "joints": [node_index[b] for b in joints], "skeleton": 0}],
        "materials": [{"name": name, "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 1.0}, "doubleSided": False}],
        "accessors": [
            {"bufferView": 0, "componentType": 5126, "count": len(mesh.P), "type": "VEC3", "min": P.min(0).tolist(), "max": P.max(0).tolist()},
            {"bufferView": 1, "componentType": 5126, "count": len(mesh.N), "type": "VEC3"},
            {"bufferView": 2, "componentType": 5126, "count": len(mesh.UV), "type": "VEC2"},
            {"bufferView": 3, "componentType": 5121, "count": len(mesh.J), "type": "VEC4"},
            {"bufferView": 4, "componentType": 5126, "count": len(mesh.W), "type": "VEC4"},
            {"bufferView": 5, "componentType": 5125, "count": len(mesh.I), "type": "SCALAR"},
            {"bufferView": 6, "componentType": 5126, "count": len(joints), "type": "MAT4"},
        ],
        "bufferViews": views, "buffers": [{"byteLength": off}],
    }
    js = pad(json.dumps(gltf, separators=(",", ":")).encode(), ch=b" ")
    bin_all = b"".join(bufs)
    glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(bin_all))
    glb += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(bin_all), 0x004E4942) + bin_all
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(glb)
    print(f"wrote {os.path.relpath(path, ROOT)}: {len(mesh.P)} verts, {len(mesh.I) // 3} tris, joints {joints}, "
          f"bounds {P.min(0).round(3).tolist()} {P.max(0).round(3).tolist()}")


# ---------------------------------------------------------- textures ------
S = 256


def png_write(path, rgb):
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(rgb.shape[0]))
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", rgb.shape[1], rgb.shape[0], 8, 2, 0, 0, 0)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def png_read_rgb(path):
    """Minimal PNG reader (8-bit RGB/RGBA, non-interlaced) so this tool stays stdlib + numpy."""
    d = open(path, "rb").read(); assert d[:8] == b"\x89PNG\r\n\x1a\n"
    off, idat, w = 8, b"", None
    while off < len(d):
        ln, tag = struct.unpack(">I4s", d[off:off + 8]); body = d[off + 8:off + 8 + ln]; off += 12 + ln
        if tag == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body); assert depth == 8 and inter == 0 and ctype in (2, 6), (depth, ctype)
            ch = 3 if ctype == 2 else 4
        elif tag == b"IDAT": idat += body
    raw = zlib.decompress(idat); stride = w * ch; out = np.zeros((h, stride), np.uint8); prev = np.zeros(stride, np.int64)
    pos = 0
    for y in range(h):
        f = raw[pos]; line = np.frombuffer(raw[pos + 1:pos + 1 + stride], np.uint8).astype(np.int64); pos += 1 + stride
        if f == 1:
            for i in range(ch, stride): line[i] = (line[i] + line[i - ch]) & 255
        elif f == 2: line = (line + prev) & 255
        elif f == 3:
            for i in range(stride): line[i] = (line[i] + ((line[i - ch] if i >= ch else 0) + prev[i]) // 2) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0; b = prev[i]; c = prev[i - ch] if i >= ch else 0
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out[y] = line; prev = line
    return out.reshape(h, w, ch)[..., :3], (out.reshape(h, w, ch)[..., 3] if ch == 4 else None)


def coat_palette(coat):
    rgb, alpha = png_read_rgb(os.path.join(BODY, f"WTAGarou_CrinosBody_{coat}.png"))
    h, w, _ = rgb.shape
    patch = rgb[int(h * .45):int(h * .75), int(w * .35):int(w * .65)].reshape(-1, 3).astype(np.float64)
    if alpha is not None:
        patch = patch[alpha[int(h * .45):int(h * .75), int(w * .35):int(w * .65)].reshape(-1) > 128]
    lum = patch.mean(1)
    base = np.median(patch, 0); dark = np.median(patch[lum <= np.percentile(lum, 20)], 0); light = np.median(patch[lum >= np.percentile(lum, 85)], 0)
    return base, dark, light


def fur_sheet(coat, seed, direction=0.0, tip_darken=0.0):
    """Procedural fur: layered strands over a mottled base. direction: strand lean (radians from +v)."""
    base, dark, light = coat_palette(coat)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float64)
    def noise(freq, sd):
        g = np.random.default_rng(sd).normal(0, 1, (freq + 1, freq + 1))
        gx = np.linspace(0, freq, S, endpoint=False); ix = gx.astype(int); fx = gx - ix
        sx = fx * fx * (3 - 2 * fx)
        a = g[np.ix_(ix, ix)]; b = g[np.ix_(ix, np.minimum(ix + 1, freq))]; c = g[np.ix_(np.minimum(ix + 1, freq), ix)]; d = g[np.ix_(np.minimum(ix + 1, freq), np.minimum(ix + 1, freq))]
        return (a * (1 - sx[None]) + b * sx[None]) * (1 - sx[:, None]) + (c * (1 - sx[None]) + d * sx[None]) * sx[:, None]
    mottle = noise(6, seed + 1) * 0.6 + noise(14, seed + 2) * 0.3 + noise(40, seed + 3) * 0.1
    mottle = (mottle - mottle.min()) / (mottle.max() - mottle.min() + 1e-9)
    img = dark * (1 - mottle)[..., None] + base * mottle[..., None]
    img = img * 0.92
    # strands: short slanted lines, light over dark, drawn in two passes
    canvas = img.copy()
    for layer, (count, length, col_mix) in enumerate(((2600, 9, 0.55), (1800, 7, 0.95))):
        for _ in range(count):
            x = rng.uniform(0, S); y = rng.uniform(0, S)
            lean = direction + rng.normal(0, 0.25)
            dx, dy = math.sin(lean), math.cos(lean)
            shade = rng.uniform(0.3, 1.0)
            col = dark * (1 - shade) + (base * (1 - col_mix) + light * col_mix) * shade
            for k in range(length):
                px, py = int(x + dx * k) % S, int(y + dy * k) % S
                fade = 1 - k / length
                canvas[py, px] = canvas[py, px] * (1 - 0.7 * fade) + col * 0.7 * fade
    img = canvas
    if tip_darken > 0:
        v = yy / S
        img = img * (1 - tip_darken * np.clip((v - 0.6) / 0.4, 0, 1))[..., None]
    return np.clip(img, 0, 255).astype(np.uint8)


# ------------------------------------------------------------- main -------
def own_file(path):
    """True when the GLB at path was written by this tool (or does not exist)."""
    if not os.path.exists(path): return True
    with open(path, "rb") as f: head = f.read(4096)
    return b"tools/build_crinos_parts.py" in head


def target(name, force):
    path = os.path.join(CLOTHES, name + ".glb")
    if force or own_file(path): return path
    alt = os.path.join(CLOTHES, name + ".base.glb")
    print(f"{path} is not this tool's output (author's model); writing {alt} instead (use --force to overwrite)")
    return alt


if __name__ == "__main__":
    force = "--force" in sys.argv
    write_glb(target("WTAGarou_CrinosLegs", force), build_leg(False), "WTAGarou_CrinosLegs")
    write_glb(target("WTAGarou_CrinosTail", force), build_tail(), "WTAGarou_CrinosTail")
    if "--tex" in sys.argv:
        # optional preview sheets only (not shipped): the tail uses the coat's Wolf PNG in game
        for i, coat in enumerate(COATS):
            png_write(os.path.join("/tmp", f"WTAGarou_CrinosTail_{coat}.preview.png"), fur_sheet(coat, 200 + i, direction=0.0, tip_darken=0.25))
