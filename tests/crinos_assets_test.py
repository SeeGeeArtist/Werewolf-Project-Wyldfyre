#!/usr/bin/env python3
"""Validate authored static head and registry assets, not in-game appearance."""
import io
import json
import re
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

root = Path(sys.argv[1])
data = (root / "common/media/models_X/WTAGarou/WTAGarou_CrinosHead.glb").read_bytes()
assert struct.unpack_from("<III", data) == (0x46546C67, 2, len(data))
length, kind = struct.unpack_from("<II", data, 12)
assert kind == 0x4E4F534A
doc = json.loads(data[20:20 + length])
binary_length, binary_kind = struct.unpack_from("<II", data, 20 + length)
binary = data[28 + length:]
assert binary_kind == 0x004E4942 and binary_length == len(binary)
assert not doc.get("skins") and not doc.get("animations"), "Static head must not include rig/clips"
assert len(doc["meshes"]) == 1 and len(doc["nodes"]) == 1, "Do not export reference body/rig"
node = doc["nodes"][0]
assert node["mesh"] == 0 and "skin" not in node
assert np.allclose(node.get("translation", [0, 0, 0]), [0, 0, 0])
assert np.allclose(node.get("rotation", [0, 0, 0, 1]), [0, 0, 0, 1])
assert np.allclose(node.get("scale", [1, 1, 1]), [1, 1, 1])
assert np.allclose(node.get("matrix", np.eye(4).flatten()), np.eye(4).flatten())

def accessor(index):
    acc = doc["accessors"][index]
    assert not acc.get("sparse"), "Sparse accessor needs explicit decoding"
    view = doc["bufferViews"][acc["bufferView"]]
    assert view.get("buffer", 0) == 0
    dtype = np.dtype({5126: "<f4", 5125: "<u4", 5123: "<u2", 5121: "u1"}[acc["componentType"]])
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
    stride = view.get("byteStride", width * dtype.itemsize)
    offset = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    end = offset + (acc["count"] - 1) * stride + width * dtype.itemsize
    assert end <= view.get("byteOffset", 0) + view["byteLength"] <= len(binary)
    result = np.ndarray((acc["count"], width), dtype=dtype, buffer=binary,
                        offset=offset, strides=(stride, dtype.itemsize))
    assert np.isfinite(result).all()
    return result

triangles = 0
for primitive in doc["meshes"][0]["primitives"]:
    assert primitive.get("mode", 4) == 4, "Export triangles"
    attrs = primitive["attributes"]
    assert set(attrs) == {"POSITION", "NORMAL", "TEXCOORD_0"}, "One intended UV map, no skinning"
    positions, normals, uv = [accessor(attrs[key]) for key in ("POSITION", "NORMAL", "TEXCOORD_0")]
    assert len(positions) == len(normals) == len(uv)
    indices = accessor(primitive["indices"]).flatten() if "indices" in primitive else np.arange(len(positions))
    assert len(indices) % 3 == 0 and indices.min() >= 0 and indices.max() < len(positions)
    triangles += len(indices) // 3
    assert np.allclose(np.linalg.norm(normals, axis=1), 1, atol=.001)
    assert (uv >= 0).all() and (uv <= 1).all()
    assert .05 < np.ptp(positions, axis=0).max() < .6, "Head-scale bounds, not full body"
    material = doc["materials"][primitive["material"]]
    assert material.get("alphaMode", "OPAQUE") == "OPAQUE", "Opaque head must not enter blend-sorting path"
    texture = doc["textures"][material["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    view = doc["bufferViews"][doc["images"][texture["source"]]["bufferView"]]
    start = view.get("byteOffset", 0)
    embedded = Image.open(io.BytesIO(binary[start:start + view["byteLength"]])).convert("RGBA")
    assert embedded.getextrema()[3] == (255, 255)
assert 0 < triangles < 10000

registry = (root / "42/media/lua/shared/WTAGarouWolfCoats.lua").read_text()
entries = re.findall(r'(\w+)\s*=\s*\{label="([^"]+)",\s*path="([^"]+)",\s*'
                     r'crinosBody="([^"]+)",\s*crinosHead="([^"]+)",\s*'
                     r'crinosLegs="([^"]+)",\s*crinosTail="([^"]+)"\}', registry)
assert {e[0] for e in entries} == {"default", "brown", "blonde", "brindle", "white", "black"}
for key, label, wolf_path, body, head, legs, tail in entries:
    assert head == f"WTAGarou_Wolf_{label}" and wolf_path == f"media/textures/Body/{head}.png"
    assert body == f"WTAGarou_CrinosBody_{label}" and "_F_" not in body
    wolf = Image.open(root / "common" / wolf_path).convert("RGBA")
    body_im = Image.open(root / f"common/media/textures/Body/{body}.png").convert("RGBA")
    assert wolf.size == (1024, 1024) and wolf.getextrema()[3] == (255, 255)
    assert body_im.size == (256, 256) and body_im.getextrema()[3] == (0, 255), \
        "Preserve authored body atlas transparency; never flatten to opaque"
    # 0.4.91: the legs mesh is UV-mapped on the vanilla body atlas, so its
    # texture is the coat's CrinosBody PNG (the author's paint, claw dot
    # included). 0.4.94: the tail is on the wolf atlas, so it shares the
    # coat's Wolf PNG with the Crinos head. Neither part has a PNG of its own.
    assert legs == body and tail == head == f"WTAGarou_Wolf_{label}", (legs, tail, head)
    for own in ("CrinosLegs", "CrinosTail"):
        assert not (root / f"common/media/textures/Body/WTAGarou_{own}_{label}.png").exists(), f"{own} has no PNG of its own"

# 0.4.90: the skinned part meshes are our own glTF binaries skinned to the
# vanilla Bip01 rig so the engine's clothing loader can skin them to the
# body's AnimationPlayer. 0.4.94: unisex, one file per part, authored by the
# author in Blender (or regenerated by tools/build_crinos_parts.py as a base).
# The third-party FBX files and mask set are gone.
import json, struct
for mesh, joint in (("CrinosLegs", b"Bip01_L_Thigh"), ("CrinosTail", b"Bip01_Spine1")):
    path = root / f"common/media/models_X/Skinned/Clothes/WTAGarou_{mesh}.glb"
    data = path.read_bytes()
    assert data[:4] == b"glTF", mesh
    jlen = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + jlen])
    generator = gltf.get("asset", {}).get("generator", "")
    assert "build_crinos_parts.py" in generator or "Blender" in generator, f"{mesh}: unexpected generator {generator!r}"
    prim = gltf["meshes"][0]["primitives"][0]
    for attr in ("POSITION", "NORMAL", "TEXCOORD_0", "JOINTS_0", "WEIGHTS_0"):
        assert attr in prim["attributes"], f"{mesh}: missing {attr}"
    assert gltf.get("skins"), f"{mesh}: not skinned"
    assert b"Bip01_Pelvis" in data and joint in data, mesh
    assert not path.with_suffix(".fbx").exists(), f"{mesh}: third-party FBX must not ship"
    for sexed in ("_M", "_F", "_m", "_f"):
        assert not (path.parent / f"WTAGarou_{mesh}{sexed}.glb").exists(), f"{mesh}: sexed variants are gone (unisex)"
assert not (root / "common/media/textures/WTAGarou/CrinosLegsMasks").exists(), "third-party mask set must not ship"
script = (root / "42/media/scripts/wtagarou_models.txt").read_text()
head_script = script.split("model WTAGarou_CrinosHead", 1)[1].split("animationsMesh", 1)[0]
for expected in ("texture = Body/WTAGarou_Wolf_Timber", "static = true", "scale = 0.6",
                 "offset = 0.0 0.0 0.0", "rotate = 180.0 0.0 -90.0", "rotate = 0.0 0.0 90.0"):
    assert expected in head_script, expected

# Reproduce the user's measured Blender quaternion W=.5, X=-.5, Y=.5, Z=-.5.
# C maps Blender Z-up to glTF Y-up. Q maps this authored head to the
# placeholder's known axes: new Y->old X, new Z->old Y, new X->old Z.
def rx(d):
    a=np.radians(d); c,s=np.cos(a),np.sin(a)
    return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def ry(d):
    a=np.radians(d); c,s=np.cos(a),np.sin(a)
    return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def rz(d):
    a=np.radians(d); c,s=np.cos(a),np.sin(a)
    return np.array([[c,-s,0],[s,c,0],[0,0,1]])
blender_q=np.array([[0,0,1],[-1,0,0],[0,-1,0]])
conversion=rx(-90)
authored_to_placeholder=conversion @ blender_q @ conversion.T
old_mount=rx(90)
for name,inverted in (("mount",True),("mount_direct",False)):
    block=re.search(r"attachment\s+"+name+r"\s*\{([^}]+)\}",head_script).group(1)
    angles=[float(v) for v in re.search(r"rotate\s*=\s*([^,]+)",block).group(1).split()]
    matrix=rx(angles[0]) @ ry(angles[1]) @ rz(angles[2])
    effective=matrix.T if inverted else matrix
    previous=(old_mount.T if inverted else old_mount) @ authored_to_placeholder
    # .52 was user-confirmed upright but facing backward. Rotate about the
    # fitted head-local X up axis, not the GLB's unmounted Euler axes.
    expected=rx(180) @ previous
    assert np.allclose(effective,expected,atol=1e-6), (name,effective,expected)
    assert np.allclose(effective[:,1],previous[:,1],atol=1e-6), "Preserve confirmed upright axis"
    assert np.allclose(effective[:,2],-previous[:,2],atol=1e-6), "Reverse facing only"
    assert np.isclose(np.linalg.det(effective),1), "Rotation, not mirror/normal flip"
    assert "offset = 0.0 0.0 0.0" in block, "Keep the fitted pivot"
for body_name in ("WTAGarou_Crinos","WTAGarou_Crinos_Female"):
    body_block=re.search(r"model\s+"+body_name+r"\s*\{([^}]+)\}",script).group(1)
    assert "scale = 1.0" in body_block, "Do not shrink the whole character"
print(f"PASS: authored static Crinos head ({triangles} triangles), opaque material, identity pivot, "
      "confirmed head orientation preserved in both native modes, head scale 0.6, and six coats. Live size check pending.")
