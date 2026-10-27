#!/usr/bin/env python3
"""Lift the wolf's tail in the locomotion clips (0.4.18).

WolfMod's Wolf_walk/run/run_V3/run_fourx hold Bip01_Tail at a constant
169.6 degrees about its local -X axis, which points the tail down AND forward
under the belly (tucked, as if frightened). Idle hangs it straight down
(149.4 deg) and run_V2 carries it almost level (83.5 deg). This rewrites every
Bip01_Tail rotation key of the given clips to a new angle about the key's own
axis, in place (same accessor size, so nothing else in the GLB moves):

    python3 tools/lift_wolf_tail.py            # defaults below
    python3 tools/lift_wolf_tail.py Wolf_walk=125 Wolf_run=105

Angles: smaller = higher tail. ~150 hangs straight down, ~90 about 25 deg
below level, run_V2's 83 is a level running tail.
"""
import json, math, pathlib, struct, sys

DEFAULTS = {"Wolf_walk": 125.0, "Wolf_run": 105.0, "Wolf_run_V3": 105.0, "Wolf_run_fourx": 105.0}
BONE = "Bip01_Tail"
root = pathlib.Path(__file__).resolve().parents[1] / "common/media/anims_X/WTAGarouWolf"

def lift(path, degrees):
    data = bytearray(path.read_bytes())
    json_len = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20 + json_len])
    bin_off = 20 + json_len + 8
    names = [n.get("name") for n in g["nodes"]]
    node = names.index(BONE)
    anim = g["animations"][0]
    outputs = [anim["samplers"][c["sampler"]]["output"] for c in anim["channels"]
               if c["target"]["node"] == node and c["target"]["path"] == "rotation"]
    assert len(outputs) == 1, f"{path.name}: expected one {BONE} rotation channel, got {len(outputs)}"
    others = [anim["samplers"][c["sampler"]]["output"] for c in anim["channels"]
              if not (c["target"]["node"] == node and c["target"]["path"] == "rotation")]
    assert outputs[0] not in others, f"{path.name}: {BONE} rotation accessor is shared"
    a = g["accessors"][outputs[0]]
    assert a["componentType"] == 5126 and a["type"] == "VEC4"
    view = g["bufferViews"][a["bufferView"]]
    base = bin_off + view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", 16)
    old_angles = []
    for i in range(a["count"]):
        off = base + i * stride
        x, y, z, w = struct.unpack_from("<4f", data, off)
        w = max(-1.0, min(1.0, w))
        s = math.sqrt(max(1e-12, 1.0 - w * w))
        ax, ay, az = x / s, y / s, z / s
        old_angles.append(math.degrees(2 * math.acos(w)))
        h = math.radians(degrees) / 2
        sh = math.sin(h)
        struct.pack_into("<4f", data, off, ax * sh, ay * sh, az * sh, math.cos(h))
    a.pop("min", None); a.pop("max", None)   # stale bounds would be wrong now
    js = json.dumps(g, separators=(",", ":")).encode()
    # Re-serialising the JSON may change its length: rebuild the container.
    while len(js) % 4:
        js += b" "
    body = bytes(data[bin_off:])
    total = 12 + 8 + len(js) + 8 + len(body)
    out = bytearray(b"glTF" + struct.pack("<II", 2, total))
    out += struct.pack("<I", len(js)) + b"JSON" + js
    out += struct.pack("<I", len(body)) + b"BIN\0" + body
    path.write_bytes(out)
    print(f"{path.name}: {BONE} {min(old_angles):.1f}-{max(old_angles):.1f} deg -> {degrees:.1f} deg ({a['count']} keys)")

targets = dict(DEFAULTS)
for arg in sys.argv[1:]:
    name, deg = arg.split("=")
    targets[name] = float(deg)
for name, deg in targets.items():
    lift(root / f"{name}.glb", deg)
