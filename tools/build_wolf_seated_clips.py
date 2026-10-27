#!/usr/bin/env python3
"""Derive a held seated pose and reversed get-up from the user's Wolf_Sit.
Never edits the input. Preserves rig/mesh and appends new animation buffers.
The held idle is a still pose, not a newly authored breathing animation.
"""
import copy
import json
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
FOLDER = ROOT / "common/media/anims_X/WTAGarouWolf"

def load(path):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from("<III", raw)
    assert magic == 0x46546C67 and version == 2 and size == len(raw)
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20+length])
    offset = 20+length
    count, kind = struct.unpack_from("<II", raw, offset)
    assert kind == 0x004E4942
    return doc, bytearray(raw[offset+8:offset+8+count])

def values(doc, binary, index):
    a = doc["accessors"][index]
    assert a["componentType"] == 5126 and "sparse" not in a
    width = {"SCALAR":1, "VEC3":3, "VEC4":4}[a["type"]]
    v = doc["bufferViews"][a["bufferView"]]
    start = v.get("byteOffset",0)+a.get("byteOffset",0)
    stride = v.get("byteStride",4*width)
    return [struct.unpack_from("<"+"f"*width,binary,start+i*stride) for i in range(a["count"])]

def append(doc, binary, rows, kind):
    binary.extend(b"\0" * (-len(binary)%4))
    start = len(binary)
    for row in rows: binary.extend(struct.pack("<"+"f"*len(row),*row))
    view = len(doc["bufferViews"])
    doc["bufferViews"].append({"buffer":0,"byteOffset":start,"byteLength":len(binary)-start})
    accessor = len(doc["accessors"])
    doc["accessors"].append({"bufferView":view,"componentType":5126,"type":kind,
        "count":len(rows),"min":[min(x) for x in zip(*rows)],"max":[max(x) for x in zip(*rows)]})
    return accessor

def build(source_doc, source_bin, name, held):
    doc, binary = copy.deepcopy(source_doc), bytearray(source_bin)
    assert len(doc["animations"]) == 1
    anim = doc["animations"][0]
    anim["name"] = name
    times = [values(source_doc,source_bin,s["input"]) for s in anim["samplers"]]
    start = min(t[0][0] for t in times)
    end = max(t[-1][0] for t in times)
    for s, t in zip(anim["samplers"],times):
        assert s.get("interpolation","LINEAR") in ("LINEAR","STEP")
        a = source_doc["accessors"][s["output"]]
        poses = values(source_doc,source_bin,s["output"])
        assert len(t) == len(poses)
        if held:
            new_times, new_poses = [(0.0,),(1.0,)], [poses[-1],poses[-1]]
        else:
            new_times = [(end-x[0],) for x in reversed(t)]
            new_poses = list(reversed(poses))
        s["input"] = append(doc,binary,new_times,"SCALAR")
        s["output"] = append(doc,binary,new_poses,a["type"])
    doc["buffers"][0]["byteLength"] = len(binary)
    encoded = json.dumps(doc,separators=(",",":")).encode()
    encoded += b" " * (-len(encoded)%4)
    binary.extend(b"\0" * (-len(binary)%4))
    raw = struct.pack("<III",0x46546C67,2,28+len(encoded)+len(binary))
    raw += struct.pack("<II",len(encoded),0x4E4F534A)+encoded
    raw += struct.pack("<II",len(binary),0x004E4942)+binary
    path = FOLDER / (name+".glb")
    path.write_bytes(raw)
    print(f"{path.name}: {'held final pose' if held else 'reversed sit'}, source range {start:.3f}..{end:.3f}s")

if __name__ == "__main__":
    doc, binary = load(FOLDER/"Wolf_Sit.glb")
    build(doc,binary,"Wolf_Sit_idle",True)
    build(doc,binary,"Wolf_getup",False)
