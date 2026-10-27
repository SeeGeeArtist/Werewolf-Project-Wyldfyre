"""Give each existing WTAGarou GLB a unique embedded clip name.

The B42 importer keys clips by the embedded name, not just the filename.
Only JSON animation.name changes; binary animation data is kept byte-for-byte.
Reference mod folders are never touched. Run with --write to apply.
"""
import argparse
import json
import pathlib
import struct

parser = argparse.ArgumentParser()
parser.add_argument("--write", action="store_true")
args = parser.parse_args()
folder = pathlib.Path(__file__).resolve().parents[1] / "common/media/anims_X/WTAGarouWolf"
for path in sorted(folder.glob("*.glb")):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and total == len(data)
    length, kind = struct.unpack_from("<II", data, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(data[20:20 + length])
    assert len(doc["animations"]) == 1, path
    current = doc["animations"][0]["name"]
    if current == path.stem:
        continue
    print(f"{path.name}: {current} -> {path.stem}")
    if args.write:
        doc["animations"][0]["name"] = path.stem
        encoded = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode()
        encoded += b" " * (-len(encoded) % 4)
        tail = data[20 + length:]
        result = struct.pack("<III", magic, version, 20 + len(encoded) + len(tail))
        result += struct.pack("<II", len(encoded), kind) + encoded + tail
        assert result[20 + len(encoded):] == tail
        path.write_bytes(result)
