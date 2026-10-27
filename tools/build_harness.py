#!/usr/bin/env python3
"""Historical STATIC placeholder wolf harness generator (0.4.23).

NOT the current skinned harness. Refuses to overwrite existing authored assets.

Writes common/media/models_X/WTAGarou/WTAGarou_Harness.glb and
common/media/textures/WTAGarou/WTAGarou_Harness.png: two elliptical straps
around the chest plus a spine band joining them on top, sized from the
WTAGarou_Wolf.glb bounds (0.34 m wide, ~1.0 m tall, 1.53 m long, native
units). Item space: glTF Y up, ring axis along Z (the spine). The model
script attachment (scripts/wtagarou_models.txt, model WTAGarou_Harness)
rotates it onto Bip01_Spine2, whose local Y runs along the spine and Z up.

Standard library only. Replace the .glb with a real mesh whenever you like;
keep the model script name and the mesh/texture paths.
"""
import json
import math
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
GLB = os.path.join(ROOT, "common", "media", "models_X", "WTAGarou", "WTAGarou_Harness.glb")
PNG = os.path.join(ROOT, "common", "media", "textures", "WTAGarou", "WTAGarou_Harness.png")
if os.path.exists(GLB) or os.path.exists(PNG):
    raise SystemExit("Refusing to overwrite authored harness assets. This retired tool makes an unrigged placeholder.")

# Metres in the wolf mesh's native units.
RX, RY = 0.20, 0.24          # chest ellipse half-width / half-height
BAND, THICK = 0.05, 0.02     # strap width along the spine, strap thickness
FRONT_Z, REAR_Z = 0.14, -0.20
SEGMENTS = 32

positions, normals, uvs, indices = [], [], [], []


def quad(a, b, c, d, n, uva, uvb, uvc, uvd):
    base = len(positions)
    for p, uv in ((a, uva), (b, uvb), (c, uvc), (d, uvd)):
        positions.append(p)
        normals.append(n)
        uvs.append(uv)
    indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])


def ring(zc):
    """Elliptical band centred on the origin in XY, BAND wide along Z."""
    z0, z1 = zc - BAND / 2, zc + BAND / 2
    for i in range(SEGMENTS):
        t0 = 2 * math.pi * i / SEGMENTS
        t1 = 2 * math.pi * (i + 1) / SEGMENTS
        for (rx, ry, sign) in ((RX, RY, 1.0), (RX - THICK, RY - THICK, -1.0)):
            p0 = (rx * math.cos(t0), ry * math.sin(t0))
            p1 = (rx * math.cos(t1), ry * math.sin(t1))
            n0 = (math.cos(t0) * sign, math.sin(t0) * sign, 0.0)
            u0, u1 = i / SEGMENTS, (i + 1) / SEGMENTS
            a, b = (p0[0], p0[1], z0), (p1[0], p1[1], z0)
            c, d = (p1[0], p1[1], z1), (p0[0], p0[1], z1)
            if sign > 0:
                quad(a, b, c, d, n0, (u0, 0), (u1, 0), (u1, 1), (u0, 1))
            else:
                quad(a, d, c, b, n0, (u0, 0), (u0, 1), (u1, 1), (u1, 0))
        # band edges (front/back faces of the strap)
        for z, nz in ((z0, -1.0), (z1, 1.0)):
            o0 = (RX * math.cos(t0), RY * math.sin(t0), z)
            o1 = (RX * math.cos(t1), RY * math.sin(t1), z)
            i0 = ((RX - THICK) * math.cos(t0), (RY - THICK) * math.sin(t0), z)
            i1 = ((RX - THICK) * math.cos(t1), (RY - THICK) * math.sin(t1), z)
            if nz > 0:
                quad(o0, o1, i1, i0, (0, 0, nz), (0, 0), (1, 0), (1, 1), (0, 1))
            else:
                quad(o0, i0, i1, o1, (0, 0, nz), (0, 0), (0, 1), (1, 1), (1, 0))


def box(x0, x1, y0, y1, z0, z1):
    faces = [
        ((x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1), (0, 1, 0)),      # top
        ((x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0), (0, -1, 0)),     # bottom
        ((x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0), (0, 0, -1)),     # back
        ((x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1), (0, 0, 1)),      # front
        ((x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0), (-1, 0, 0)),     # left
        ((x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1), (1, 0, 0)),      # right
    ]
    for a, b, c, d, n in faces:
        quad(a, b, c, d, n, (0, 0), (1, 0), (1, 1), (0, 1))


ring(FRONT_Z)
ring(REAR_Z)
# spine band on top, sitting on the outer surface of both rings
box(-0.035, 0.035, RY - THICK, RY, REAR_Z, FRONT_Z)
# short belly band underneath (keeps the straps from reading as loose hoops)
box(-0.035, 0.035, -RY, -RY + THICK, REAR_Z, FRONT_Z)


def pack(fmt, seq):
    return b"".join(struct.pack(fmt, *v) if isinstance(v, tuple) else struct.pack(fmt, v) for v in seq)


pos_bin = pack("<3f", positions)
nrm_bin = pack("<3f", normals)
uv_bin = pack("<2f", uvs)
idx_bin = pack("<H", indices)


def pad(b, n=4, ch=b"\x00"):
    return b + ch * ((n - len(b) % n) % n)


bufs = [pad(pos_bin), pad(nrm_bin), pad(uv_bin), pad(idx_bin)]
views, offset = [], 0
for i, b in enumerate(bufs):
    views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(b),
                  "target": 34963 if i == 3 else 34962})
    offset += len(b)
mins = [min(p[i] for p in positions) for i in range(3)]
maxs = [max(p[i] for p in positions) for i in range(3)]
gltf = {
    "asset": {"version": "2.0", "generator": "WTAGarou tools/build_harness.py"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "WTAGarou_Harness", "mesh": 0}],
    "meshes": [{"name": "WTAGarou_Harness", "primitives": [{
        "attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2},
        "indices": 3, "material": 0, "mode": 4}]}],
    # No glTF image reference: like WTAGarou_Wolf.glb the texture comes from
    # the model script (texture = WTAGarou/WTAGarou_Harness).
    "materials": [{"name": "WTAGarou_Harness", "pbrMetallicRoughness": {
        "metallicFactor": 0.0, "roughnessFactor": 0.9}}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": len(positions), "type": "VEC3", "min": mins, "max": maxs},
        {"bufferView": 1, "componentType": 5126, "count": len(normals), "type": "VEC3"},
        {"bufferView": 2, "componentType": 5126, "count": len(uvs), "type": "VEC2"},
        {"bufferView": 3, "componentType": 5123, "count": len(indices), "type": "SCALAR"},
    ],
    "bufferViews": views,
    "buffers": [{"byteLength": offset}],
}
json_bin = pad(json.dumps(gltf, separators=(",", ":")).encode(), ch=b" ")
bin_all = b"".join(bufs)
glb = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(json_bin) + 8 + len(bin_all))
glb += struct.pack("<II", len(json_bin), 0x4E4F534A) + json_bin
glb += struct.pack("<II", len(bin_all), 0x004E4942) + bin_all
os.makedirs(os.path.dirname(GLB), exist_ok=True)
with open(GLB, "wb") as f:
    f.write(glb)


def png(path, size=64):
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            # dark oiled leather with a lighter stitch line along the middle
            r, g, b = 58, 38, 26
            if size * 0.44 < y < size * 0.56 and (x // 4) % 2 == 0:
                r, g, b = 150, 130, 90
            n = ((x * 7 + y * 13) % 11) - 5
            row += bytes((max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n))))
        rows.append(bytes(row))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)
    body = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(body)


png(PNG)
print("wrote", GLB, len(positions), "vertices", len(indices) // 3, "triangles; bounds", mins, maxs)
print("wrote", PNG)
