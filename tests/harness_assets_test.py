"""Authored harness contract: inspect, never regenerate the user's GLB."""
import json
import math
from pathlib import Path
import re
import struct
import sys

root = Path(sys.argv[1])
media = root / "common/media"
checks = 0

def check(ok, message):
    global checks
    checks += 1
    assert ok, message

def load(path):
    blob = path.read_bytes()
    magic, version, size = struct.unpack_from("<III", blob)
    check(magic == 0x46546C67 and version == 2 and size == len(blob), str(path))
    count, kind = struct.unpack_from("<II", blob, 12)
    check(kind == 0x4E4F534A, "JSON chunk")
    return json.loads(blob[20:20+count]), blob[28+count:]

doc, binary = load(media / "models_X/WTAGarou/WTAGarou_Harness.glb")
wolf, _ = load(media / "models_X/Skinned/WTAGarou_Wolf.glb")
check(len(doc["meshes"]) == 1 and len(doc["skins"]) == 1, "one harness mesh and skin, no backup/wolf meshes")
check(not doc.get("animations"), "gear must use current wolf animation, not bundled clips")
names = [doc["nodes"][i]["name"] for i in doc["skins"][0]["joints"]]
wolf_names = [wolf["nodes"][i]["name"] for i in wolf["skins"][0]["joints"]]
check(len(names) == len(set(names)) and set(names) == set(wolf_names), "unique joints match wolf by NAME, not array order")
check(any(n.get("skin") == 0 and "mesh" in n for n in doc["nodes"]), "mesh references skin")

def read(index, fmt):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", struct.calcsize(fmt))
    return [struct.unpack_from(fmt, binary, start+i*stride) for i in range(acc["count"])]

used = set()
vertices = 0
for primitive in doc["meshes"][0]["primitives"]:
    attrs = primitive["attributes"]
    check({"POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"} <= attrs.keys(), "all rendering/skinning attributes")
    check("TEXCOORD_1" not in attrs and "JOINTS_1" not in attrs, "one UV set; at most four influences")
    check(primitive.get("mode", 4) == 4, "triangles")
    joint_type = doc["accessors"][attrs["JOINTS_0"]]["componentType"]
    joints = read(attrs["JOINTS_0"], "<4B" if joint_type == 5121 else "<4H")
    weights = read(attrs["WEIGHTS_0"], "<4f")
    check(len(joints) == len(weights) == doc["accessors"][attrs["POSITION"]]["count"], "matching attribute counts")
    vertices += len(joints)
    check(all(all(0 <= j < len(names) for j in row) for row in joints), "joint indices in skin bounds")
    check(all(all(math.isfinite(w) and 0 <= w <= 1 for w in row)
              and abs(sum(row)-1) < 1e-4 for row in weights), "all vertices weighted and normalized")
    for js, ws in zip(joints, weights):
        used.update(names[j] for j, w in zip(js, ws) if w > 0.001)
    check(all(all(math.isfinite(v) for v in uv) for uv in read(attrs["TEXCOORD_0"], "<2f")), "finite UVs")
check({"Bip01_Spine1", "Bip01_Spine2", "Bip01_Spine3"} <= used, "weights span multiple spine bones")
check(doc["accessors"][doc["skins"][0]["inverseBindMatrices"]]["count"] == len(names), "bind matrix per joint")
scripts = (root / "42/media/scripts/wtagarou_models.txt").read_text()
for suffix in ("", "_Camo"):
    match = re.search(r"model WTAGarou_Harness"+suffix+r"\s*\{(.*?)(?=\n    model |\n\})", scripts, re.S)
    block = match.group(1)
    check("static = false," in block and "animationsMesh = WTAGarou_Wolf," in block, "skinned "+suffix)
    check("mesh = WTAGarou/WTAGarou_Harness," in block, "same GLB "+suffix)
    check("attachment WTAGarou_Harness" not in block, "no rigid self mount "+suffix)
    for kind in ("Harness", "Saddlebags"):
        png = media / f"textures/WTAGarou/WTAGarou_{kind}{suffix}.png"
        header = png.read_bytes()[:29]
        check(header[:8] == b"\x89PNG\r\n\x1a\n" and header[24] == 8, "8-bit texture "+png.name)
print(f"PASS: {checks} harness asset contracts; {vertices} weighted vertices; spine influences {sorted(used)}.")
