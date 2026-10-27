#!/usr/bin/env python3
"""Build models_X/Skinned/WTAGarou_Wolf.glb from the mesh embedded in an animation GLB.

The WolfMod low-poly body (1687 vertices) weights every head vertex about
0.29 to Bip01_Head and the rest to Bip01_Neck and Bip01_Spine1, so the head
collapses toward the spine whenever the neck bends (eat, walk bob). The mesh
embedded in the animation GLBs (3433 vertices, same texture layout) carries
the proper weights (dominant weight ~0.7-0.8, <1 cm drift). This script copies
that mesh, skin and node tree, drops the animation and prunes unused buffer
data. Usage: python3 tools/build_wolf_body.py [source.glb] [target.glb]
"""
import json, struct, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[1] / "common/media"
src = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / "anims_X/WTAGarouWolf/Wolf_walk.glb"
dst = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else root / "models_X/Skinned/WTAGarou_Wolf.glb"

data = src.read_bytes()
assert data[:4] == b"glTF", "not a GLB"
json_len = struct.unpack_from("<I", data, 12)[0]
g = json.loads(data[20:20 + json_len])
bin_off = 20 + json_len
bin_len = struct.unpack_from("<I", data, bin_off)[0]
assert data[bin_off + 4:bin_off + 8] == b"BIN\x00"
blob = data[bin_off + 8:bin_off + 8 + bin_len]

g.pop("animations", None)
used = set()
for mesh in g["meshes"]:
    for prim in mesh["primitives"]:
        used.update(prim["attributes"].values())
        if "indices" in prim:
            used.add(prim["indices"])
for skin in g.get("skins", []):
    if "inverseBindMatrices" in skin:
        used.add(skin["inverseBindMatrices"])
old_acc = g["accessors"]
acc_map = {old: new for new, old in enumerate(sorted(used))}
new_acc, new_views, out = [], [], bytearray()
for old in sorted(used):
    a = dict(old_acc[old])
    view = g["bufferViews"][a["bufferView"]]
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    comp = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}[a["componentType"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    size = comp * n
    stride = view.get("byteStride", size)
    chunk = bytearray()
    for i in range(a["count"]):
        chunk += blob[start + i * stride:start + i * stride + size]
    while len(out) % 4:
        out += b"\0"
    nv = {"buffer": 0, "byteOffset": len(out), "byteLength": len(chunk)}
    if "target" in view:
        nv["target"] = view["target"]
    a["bufferView"] = len(new_views)
    a.pop("byteOffset", None)
    new_views.append(nv)
    out += chunk
    new_acc.append(a)
for mesh in g["meshes"]:
    for prim in mesh["primitives"]:
        prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
        if "indices" in prim:
            prim["indices"] = acc_map[prim["indices"]]
for skin in g.get("skins", []):
    if "inverseBindMatrices" in skin:
        skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
g["accessors"], g["bufferViews"] = new_acc, new_views
while len(out) % 4:
    out += b"\0"
g["buffers"] = [{"byteLength": len(out)}]
g.setdefault("asset", {})["generator"] = (g["asset"].get("generator", "") + " + WTAGarou tools/build_wolf_body.py").strip()
js = json.dumps(g, separators=(",", ":")).encode()
while len(js) % 4:
    js += b" "
total = 12 + 8 + len(js) + 8 + len(out)
with open(dst, "wb") as f:
    f.write(b"glTF" + struct.pack("<II", 2, total))
    f.write(struct.pack("<I", len(js)) + b"JSON" + js)
    f.write(struct.pack("<I", len(out)) + b"BIN\x00" + bytes(out))
print(f"wrote {dst} ({total} bytes) from {src.name}: nodes={len(g['nodes'])} accessors={len(new_acc)}")
