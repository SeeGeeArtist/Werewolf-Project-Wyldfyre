#!/usr/bin/env python3
"""Hold the wolf's skinned root (Bip01) in place in locomotion clips.

Why: the imported wolf clips bake the forward travel into BOTH the skinned
Bip01 root and the unskinned Translation_Data marker.  Project Zomboid only
consumes (and only counter-translates) the deferred-movement marker; the
skinned root's travel is drawn on top of the game's own character movement,
so the body slides ahead at double speed and snaps back every cycle.  Human
clips keep Bip01 in place and move the character purely through the marker.

This tool rewrites the Bip01 translation samplers' X and Z values to the
first-frame value (vertical bob on Y is kept) directly in the GLB binary.
Idempotent: running it twice changes nothing.  Only the listed locomotion
clips are touched; Translation_Data is never modified.
"""
import json
import pathlib
import struct
import sys

CLIPS = ("Wolf_walk", "Wolf_run", "Wolf_run_fourx", "Wolf_run_V2", "Wolf_run_V3")
ROOT = "Bip01"


def bake(path: pathlib.Path) -> tuple[int, float]:
    raw = bytearray(path.read_bytes())
    json_len = struct.unpack_from("<I", raw, 12)[0]
    doc = json.loads(raw[20:20 + json_len])
    bin_offset = 28 + json_len  # 12 header + 8 json chunk header + json + 8 bin chunk header
    changed = 0
    max_delta = 0.0
    for anim in doc.get("animations", []):
        for channel in anim["channels"]:
            if channel["target"]["path"] != "translation":
                continue
            if doc["nodes"][channel["target"]["node"]].get("name") != ROOT:
                continue
            sampler = anim["samplers"][channel["sampler"]]
            accessor = doc["accessors"][sampler["output"]]
            assert accessor["componentType"] == 5126 and accessor["type"] == "VEC3"
            view = doc["bufferViews"][accessor["bufferView"]]
            stride = view.get("byteStride", 12)
            base = bin_offset + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
            first = struct.unpack_from("<fff", raw, base)
            for i in range(accessor["count"]):
                off = base + i * stride
                x, y, z = struct.unpack_from("<fff", raw, off)
                max_delta = max(max_delta, abs(x - first[0]), abs(z - first[2]))
                if (x, z) != (first[0], first[2]):
                    struct.pack_into("<fff", raw, off, first[0], y, first[2])
                    changed += 1
            # Keep accessor min/max honest so validators do not complain.
            if "min" in accessor and "max" in accessor:
                accessor["min"][0] = accessor["max"][0] = first[0]
                accessor["min"][2] = accessor["max"][2] = first[2]
    if changed:
        new_json = json.dumps(doc, separators=(",", ":")).encode()
        while len(new_json) % 4:
            new_json += b" "
        bin_chunk = bytes(raw[20 + json_len:])
        out = bytearray()
        out += struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(new_json) + len(bin_chunk))
        out += struct.pack("<II", len(new_json), 0x4E4F534A) + new_json
        out += bin_chunk
        path.write_bytes(out)
    return changed, max_delta


def main(root: pathlib.Path) -> int:
    anims = root / "WTAGarou/common/media/anims_X/WTAGarouWolf"
    for name in CLIPS:
        path = anims / f"{name}.glb"
        if not path.exists():
            print(f"skip {name}: missing")
            continue
        changed, delta = bake(path)
        print(f"{name}: root frames rewritten={changed}; previous max root travel={delta:.3f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2])))
