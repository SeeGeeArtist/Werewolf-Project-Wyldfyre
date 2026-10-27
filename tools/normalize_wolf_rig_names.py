#!/usr/bin/env python3
"""Disambiguate GLB export helpers without altering joints, weights or motion.

The skin root and its non-joint wrapper were both named Bip01 in some exports.
The mesh also had an unused Translation_Data helper colliding with the joint.
Native name-based import must map clips to joints, not the export wrapper.
"""
import json
import pathlib
import struct


def normalize(path):
    raw = path.read_bytes()
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20 + length])
    joints = {j for skin in doc.get("skins", []) for j in skin["joints"]}
    changed = False
    # Walk/sprint/idle use Bip01_Root where jog/death and the mesh use Bip01.
    # They are the same skinned root, not different bones.
    for i in joints:
        if doc["nodes"][i].get("name") == "Bip01_Root":
            doc["nodes"][i]["name"] = "Bip01"
            changed = True
    for i, node in enumerate(doc["nodes"]):
        if i in joints:
            continue
        # The wrapper is present under differing exporter names; normalize by
        # hierarchy, not merely by the duplicate spelling in some clips.
        if any(c in joints and doc["nodes"][c].get("name") == "Bip01"
               for c in node.get("children", [])):
            changed |= node.get("name") != "WTAGarou_RigRoot"
            node["name"] = "WTAGarou_RigRoot"
        elif node.get("name") == "Translation_Data":
            node["name"] = "WTAGarou_UnusedTranslation_Data"
            changed = True
    if changed:
        payload = json.dumps(doc, separators=(",", ":")).encode()
        payload += b" " * (-len(payload) % 4)
        tail = raw[20 + length:]
        output = struct.pack("<III", 0x46546C67, 2, 20 + len(payload) + len(tail))
        output += struct.pack("<II", len(payload), kind) + payload + tail
        assert output[20 + len(payload):] == tail  # binary motion is untouched
        path.write_bytes(output)
    return changed


if __name__ == "__main__":
    root = pathlib.Path(__file__).resolve().parents[1] / "common/media"
    paths = [root / "models_X/Skinned/WTAGarou_Wolf.glb"]
    paths += sorted((root / "anims_X/WTAGarouWolf").glob("*.glb"))
    print("Normalized", sum(normalize(path) for path in paths), "WTAGarou GLBs")
