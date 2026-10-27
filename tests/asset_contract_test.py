"""Validate shipped GLBs and timing reference data, not engine rendering."""
import json
import pathlib
import struct
import sys
import xml.etree.ElementTree as ET
import zipfile

root = pathlib.Path(sys.argv[1])
checks = 0

def check(value, message):
    global checks
    checks += 1
    assert value, message

def glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    check(magic == 0x46546C67 and version == 2 and total == len(data), str(path))
    length, kind = struct.unpack_from("<II", data, 12)
    check(kind == 0x4E4F534A, "GLB JSON chunk")
    return json.loads(data[20:20+length])

def translation_track(path, bone):
    """Return the list of (x, y, z) translation keys for `bone`, or None."""
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_offset = 20 + json_len + 8
    anim = doc["animations"][0]
    for channel in anim["channels"]:
        if channel["target"].get("path") != "translation":
            continue
        if doc["nodes"][channel["target"]["node"]].get("name") != bone:
            continue
        accessor = doc["accessors"][anim["samplers"][channel["sampler"]]["output"]]
        view = doc["bufferViews"][accessor["bufferView"]]
        base = bin_offset + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", 12)
        return [struct.unpack_from("<fff", data, base + i * stride) for i in range(accessor["count"])]
    return None

media = root / "common/media"
mesh = glb(media / "models_X/Skinned/WTAGarou_Wolf.glb")

# 0.4.10 motion contract: locomotion travel lives ONLY in the Translation_Data
# marker. The skinned Bip01 root is held flat in x/z (the y bob stays), because
# the engine counters a single deferred bone and any travel left on the other
# bone doubles the visible speed and snaps the model back each loop.
for clip, min_travel in (("walk", 0.5), ("run", 1.5), ("run_fourx", 3.0), ("run_V2", 0.5), ("run_V3", 0.5)):
    path = media / f"anims_X/WTAGarouWolf/Wolf_{clip}.glb"
    root_keys = translation_track(path, "Bip01")
    check(root_keys is not None, f"Wolf_{clip} has a Bip01 translation track")
    dx = max(k[0] for k in root_keys) - min(k[0] for k in root_keys)
    dz = max(k[2] for k in root_keys) - min(k[2] for k in root_keys)
    check(dx < 1e-4 and dz < 1e-4, f"Wolf_{clip} Bip01 x/z held flat (dx={dx:.4f} dz={dz:.4f})")
    marker = translation_track(path, "Translation_Data")
    check(marker is not None, f"Wolf_{clip} keeps a Translation_Data track")
    travel = max(abs(marker[-1][i] - marker[0][i]) for i in (0, 2))
    check(travel >= min_travel, f"Wolf_{clip} Translation_Data still carries travel ({travel:.3f})")

bones = {node.get("name") for node in mesh["nodes"]}
for bone in ("Bip01_Jaw", "Translation_Data", "Bip01"):
    check(bone in bones, f"verified bone {bone}")
for clip in ("idle", "walk", "run", "attack", "hitreaction", "Sit", "Sit_idle", "getup", "eat", "death", "dead",
             "run_V2", "run_V3", "run_fourx", "OnHook"):
    name = "Wolf_" + clip
    asset = glb(media / f"anims_X/WTAGarouWolf/{name}.glb")
    check(name in [a["name"] for a in asset["animations"]], f"embedded clip {name}")
    joints = {j for skin in asset["skins"] for j in skin["joints"]}
    names = [asset["nodes"][j]["name"] for j in joints]
    check("Bip01" in names and "Bip01_Root" not in names, f"canonical skinned root {name}")
    check(sum(n.get("name") == "Bip01" for n in asset["nodes"]) == 1, f"unambiguous root {name}")
check(sum(n.get("name") == "Bip01" for n in mesh["nodes"]) == 1, "mesh root unambiguous")
check(sum(n.get("name") == "Translation_Data" for n in mesh["nodes"]) == 1, "mesh marker unambiguous")
check((media / "textures/Body/WTAGarou_Wolf_Timber.png").is_file(), "default Timber wolf texture exists")
check((media / "textures/Body/WTAGarou_Wolf_Blonde.png").is_file(), "blonde wolf texture exists")
# Verify every pose channel in the generated seated hold and reverse.
sys.path.insert(0, str(root / "tools"))
sys.dont_write_bytecode = True
from build_wolf_seated_clips import load, values
sit_doc, sit_bin = load(media / "anims_X/WTAGarouWolf/Wolf_Sit.glb")
for name, held in (("Wolf_Sit_idle", True), ("Wolf_getup", False)):
    doc, binary = load(media / f"anims_X/WTAGarouWolf/{name}.glb")
    check(doc["nodes"] == sit_doc["nodes"] and doc["skins"] == sit_doc["skins"], f"{name} keeps original rig")
    src = sit_doc["animations"][0]
    dst = doc["animations"][0]
    check(src["channels"] == dst["channels"], f"{name} preserves pose channels")
    for before, after in zip(src["samplers"], dst["samplers"]):
        poses = values(sit_doc, sit_bin, before["output"])
        actual = values(doc, binary, after["output"])
        check(actual == ([poses[-1], poses[-1]] if held else list(reversed(poses))),
              f"{name} exact held/reversed pose samples")
        times = values(doc, binary, after["input"])
        check(all(a[0] < b[0] for a, b in zip(times, times[1:])), f"{name} strictly increasing times")
models = (root / "42/media/scripts/wtagarou_models.txt").read_text()
check(models.count("texture = Body/WTAGarou_Wolf_Timber,") == 3,
      "both wolf scripts and the wolf-UV Crinos head use default Timber")
check(models.count("bone = Bip01_Jaw,") == 2, "jaw attachment is not guessed")
corpse_node = ET.parse(root / "42/media/AnimSets/WTAGarouCorpse/deadbody/deadbody.xml").getroot()
check(corpse_node.findtext("m_AnimName") == "Wolf_dead", "corpse-only graph uses packaged wolf dead pose")
check(corpse_node.findtext("m_deferredBoneAxis") == "Y", "corpse graph retains wolf axis")
reference = root.parent / "SkullysFasterAttackSpeed/42/media/AnimSets/player/melee"
for relative, delay in {
    "1handed/1HDefault.xml": 12, "2handed/2HDefault.xml": 12,
    "1handed/KnifeDefault.xml": 1, "2handed/SpearDefault.xml": 8,
    "heavy/HeavyDefault.xml": 4,
}.items():
    node = ET.parse(reference / relative).getroot()
    values = [int(e.findtext("m_ParameterValue")) for e in node.findall("m_Events")
              if e.findtext("m_EventName") == "SetMeleeDelay"]
    check(values == [delay], f"Skully reference delay {relative}")
player_nodes = list((root / "42/media/AnimSets/player").rglob("*.xml"))
check(sorted(p.relative_to(root / "42/media/AnimSets/player").as_posix() for p in player_nodes)
      == ["actions/WTAGarouHowl.xml", "shove/WTAGarouCrinosClaw.xml", "shoveAim/WTAGarouCrinosClaw.xml"],
      "only additive nodes (claw in shove + shoveAim, 0.4.71 authored howl in actions); no vanilla node filenames overridden")
howl_node = ET.parse(root / "42/media/AnimSets/player/actions/WTAGarouHowl.xml").getroot()
check(howl_node.findtext("m_AnimName") == "Bob_WTAGarouHowl" and howl_node.findtext("m_Looped") == "true",
      "authored howl node plays the looped Bob_WTAGarouHowl clip")
howl_conditions = [(c.findtext("m_Name"), c.findtext("m_StringValue")) for c in howl_node.findall("m_Conditions")]
check(howl_conditions == [("PerformingAction", "WTAGarouHowl")],
      "authored howl node is selected only by the action name the howl sets")
check(len(howl_node.findall("m_SubStateBoneWeights")) >= 5, "authored howl keeps the gait layer on the legs (upper-body weights)")
with zipfile.ZipFile(root / "42/media/java/client/WTAGarouVisuals.jar") as jar:
    check(not any(n.startswith("zombie/") for n in jar.namelist()), "no game stubs in distributed jar")

# 0.4.11 sound bank: every clip the sound script references ships in
# common/media/sound, except the two Crinos voice files the mod author adds
# locally (listed here on purpose; the script may reference them, the repo
# does not have to carry them).
import re
sounds = (root / "42/media/scripts/wtagarou_sounds.txt").read_text()
author_supplied = {"WTAGarou_Crinos_Growl.ogg", "WTAGarou_Crinos_Roar_Bark.ogg"}
clips = re.findall(r"file = media/sound/([^,\s]+)", sounds)
check(len(clips) >= 12, f"sound bank has the wolf/crinos clips ({len(clips)})")
for clip in clips:
    if clip in author_supplied:
        continue
    check((media / "sound" / clip).is_file(), f"sound clip shipped: {clip}")
for name in ("WTAGarou_Howl", "WTAGarou_CrinosGrowl", "WTAGarou_CrinosRoar", "WTAGarou_WolfStep",
             "WTAGarou_WolfBark", "WTAGarou_WolfGrowl", "WTAGarou_WolfAttack", "WTAGarou_WolfFallOver",
             "WTAGarou_WolfSniff", "WTAGarou_WolfDeath", "WTAGarou_HispoBark", "WTAGarou_HispoGrowl",
             "WTAGarou_FormShift", "WTAGarou_CrinosShift", "WTAGarou_CrinosShiftTimer"):
    check(f"sound {name}\n" in sounds, f"sound entry {name}")
check("sound WTAGarou_Growl\n" not in sounds, "old WTAGarou_Growl entry retired")
check(sounds.count("Wolf_Mod_Step_0") == 3, "wolf step bank has three clips")
lua_client = root / "42/media/lua/client"
for f in lua_client.glob("*.lua"):
    check('"WTAGarou_Growl"' not in f.read_text(), f"{f.name} does not reference the retired growl entry")

# Saddlebag visual (0.4.89): own generated mesh + textures (tools/build_saddlebags.py),
# the model script points at them, and the wolf attachments use a real wolf bone.
check((media / "models_X/WTAGarou/WTAGarou_Saddlebags.glb").is_file(), "saddlebag mesh (own GLB)")
check(not (media / "models_X/WTAGarou/WTAGarou_Saddlebags.fbx").exists(), "0.4.89: the Horse Mod saddlebag FBX no longer ships")
check((media / "textures/WTAGarou/WTAGarou_Saddlebags.png").is_file() and (media / "textures/WTAGarou/WTAGarou_Saddlebags_Camo.png").is_file(), "saddlebag textures (own)")
_sb = (media / "models_X/WTAGarou/WTAGarou_Saddlebags.glb").read_bytes()
check(_sb[:4] == b"glTF" and b"tools/build_saddlebags.py" in _sb, "saddlebag GLB carries the generator tag (not a donor file)")
check("model WTAGarou_Saddlebags" in models and "mesh = WTAGarou/WTAGarou_Saddlebags," in models, "saddlebag model script")
check(models.count("attachment WTAGarou_Saddlebags") == 4, "saddlebag attachment on both wolves and both bag variants")
for m in re.finditer(r"bone = ([A-Za-z0-9_]+),", models):
    check(m.group(1) in bones, f"attachment bone exists in the wolf rig: {m.group(1)}")
items = (root / "42/media/scripts/wtagarou_items.txt").read_text()
check("item WolfSaddlebagVisual" in items and "StaticModel = WTAGarou_Saddlebags," in items, "hidden saddlebag stand-in item")

# 0.4.15 radial icons: moon-phase form set + crossed-out T-shirt strip icon.
# 48x48 RGBA, non-interlaced (the engine's PNG reader rejects Adam7).
import struct, zlib
def png_header(path):
    data = path.read_bytes()
    check(data[:8] == b"\x89PNG\r\n\x1a\n", f"{path.name} is a PNG")
    w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", data[16:29])
    return w, h, depth, ctype, interlace
ui = root / "42/media/ui/WTAGarou"
for name in ("homid", "glabro", "crinos", "hispo", "lupus", "howl", "strip", "dress"):
    icon = ui / f"wta_{name}.png"
    check(icon.is_file(), f"radial icon exists: wta_{name}.png")
    w, h, depth, ctype, interlace = png_header(icon)
    check((w, h) == (48, 48), f"wta_{name}.png is 48x48: {w}x{h}")
    check(interlace == 0, f"wta_{name}.png is not interlaced")
    check(ctype == 6, f"wta_{name}.png is RGBA")
# 0.4.82 scattered-silver tiles: 128x256 RGBA iso tiles whose art sits on
# the FLOOR DIAMOND. The engine draws a tile's canvas with its top-left at
# the square's screen point minus (32, 96) x tileScale (IsoObject.offsetX/Y),
# so on a 128x256 canvas the floor diamond is the bottom 64 rows
# (192..255, centre 224). Art centred on the canvas (rows ~97..159) floats
# a body height above the floor (Oct 23 screenshot 20A6D3). The user's
# files were shifted down 96 px to put them on the diamond.
FLOOR_TOP, FLOOR_BOTTOM = 192, 255
try:
    from PIL import Image as _PILImage
except ImportError:
    _PILImage = None
for i in range(4):
    tile = root / "common/media/textures/WTAGarou" / f"WTAGarou_SilverScatter_{i}.png"
    check(tile.is_file(), f"scatter tile variant {i} exists")
    w, h, depth, ctype, interlace = png_header(tile)
    check((w, h) == (128, 256) and ctype == 6 and interlace == 0, f"scatter tile {i} is a 128x256 RGBA non-interlaced tile: {w}x{h} ctype {ctype} il {interlace}")
    if _PILImage is not None:
        bbox = _PILImage.open(tile).convert("RGBA").split()[-1].getbbox()
        check(bbox is not None and bbox[1] >= FLOOR_TOP and bbox[3] - 1 <= FLOOR_BOTTOM,
              f"scatter tile {i}: opaque pixels sit on the floor diamond (rows {FLOOR_TOP}..{FLOOR_BOTTOM}), got {bbox}")
        check(bbox is not None and abs(((bbox[0] + bbox[2]) / 2) - 64) <= 4, f"scatter tile {i}: art centred horizontally, got {bbox}")

radial = (root / "42/media/lua/client/WTAGarouRadial.lua").read_text()
check('iconFor("resist")' in radial, "map radial uses the Resist icon")
emote = (root / "42/media/lua/client/WTAGarouEmote.lua").read_text()
check('iconFor("strip")' in emote, "social radial uses the strip icon")
check('iconFor("dress")' in emote and 'iconFor("howl")' in emote, "social radial offers Dress and Howl with their icons")
check('iconFor("strip")' not in radial and 'iconFor("dress")' not in radial,
      "wardrobe actions do not crowd the map radial")
check("WTAGarou_FormRadial" not in radial and "setJoypadFocus" not in radial,
      "no standalone keybind or custom focus acquisition")
check((root / "42/media/lua/shared/WTAGarouWardrobe.lua").is_file() and (root / "42/media/lua/client/WTAGarouDress.lua").is_file(),
      "wardrobe (shared) and dress (client) modules present")
check((root / "tools/gen_radial_icons.py").is_file(), "icon generator committed")
icon = root / "42/icon.png"
if icon.is_file():
    check(png_header(icon)[4] == 0, "mod icon.png is not interlaced (unsupported interlace method)")

# 0.4.18 skin-weight contract: the WolfMod low-poly body weighted every head
# vertex ~0.29 to Bip01_Head and the rest to Bip01_Neck/Bip01_Spine1, so the
# head collapsed toward the spine whenever the neck bent (eat, walk bob). The
# body must carry the animation GLBs' weights (tools/build_wolf_body.py):
# head-dominant vertices average >= 0.6 on their dominant bone and no head
# vertex leans on Bip01_Spine1.
def skin_weights(path):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_offset = 20 + json_len + 8
    prim = doc["meshes"][0]["primitives"][0]
    def read(index, fmt, width):
        accessor = doc["accessors"][index]
        view = doc["bufferViews"][accessor["bufferView"]]
        base = bin_offset + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", struct.calcsize(fmt))
        return [struct.unpack_from(fmt, data, base + i * stride) for i in range(accessor["count"])]
    joints_acc = doc["accessors"][prim["attributes"]["JOINTS_0"]]
    jfmt = "<4B" if joints_acc["componentType"] == 5121 else "<4H"
    joints = read(prim["attributes"]["JOINTS_0"], jfmt, 4)
    weights = read(prim["attributes"]["WEIGHTS_0"], "<4f", 4)
    names = [doc["nodes"][j]["name"] for j in doc["skins"][0]["joints"]]
    return names, joints, weights

names, joints, weights = skin_weights(media / "models_X/Skinned/WTAGarou_Wolf.glb")
head = names.index("Bip01_Head")
spine1 = names.index("Bip01_Spine1")
dominant, leaning = [], 0
for j, w in zip(joints, weights):
    top = max(range(4), key=lambda i: w[i])
    if j[top] == head:
        dominant.append(w[top])
        if any(j[i] == spine1 and w[i] > 0.05 for i in range(4)):
            leaning += 1
check(len(dominant) > 100, f"wolf body has head-dominant vertices ({len(dominant)})")
mean_dom = sum(dominant) / len(dominant)
check(mean_dom >= 0.6, f"wolf body head vertices are firmly weighted to Bip01_Head (mean {mean_dom:.2f})")
check(leaning == 0, f"no wolf head vertex leans on Bip01_Spine1 ({leaning})")
# 0.4.73: the author's Oct 18 remodel (commit e15e3ec) is a leaner 1290-vertex
# wolf; the floor only guards against a placeholder/empty export now.
check(len(joints) >= 1000, f"wolf body is a real skinned mesh, not a placeholder ({len(joints)} vertices)")

# 0.4.18 tail contract (tools/lift_wolf_tail.py): WolfMod tucked the tail
# under the belly (Bip01_Tail 169.6 deg) in every locomotion clip. Walk hangs
# it down-and-back (125), the runs carry it lower than level (105); idle and
# run_V2 are untouched.
import math
def rotation_angles(path, bone):
    data = path.read_bytes()
    json_len = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + json_len])
    bin_offset = 20 + json_len + 8
    anim = doc["animations"][0]
    for channel in anim["channels"]:
        if channel["target"].get("path") != "rotation":
            continue
        if doc["nodes"][channel["target"]["node"]].get("name") != bone:
            continue
        accessor = doc["accessors"][anim["samplers"][channel["sampler"]]["output"]]
        view = doc["bufferViews"][accessor["bufferView"]]
        base = bin_offset + view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        stride = view.get("byteStride", 16)
        out = []
        for i in range(accessor["count"]):
            w = struct.unpack_from("<4f", data, base + i * stride)[3]
            out.append(math.degrees(2 * math.acos(max(-1.0, min(1.0, w)))))
        return out
    return None
for clip, expect in (("walk", 125.0), ("run", 105.0), ("run_V3", 105.0), ("run_fourx", 105.0)):
    angles = rotation_angles(media / f"anims_X/WTAGarouWolf/Wolf_{clip}.glb", "Bip01_Tail")
    check(angles and all(abs(a - expect) < 0.5 for a in angles),
          f"Wolf_{clip} tail lifted to {expect} deg (got {angles and [round(a, 1) for a in angles]})")
idle_angles = rotation_angles(media / "anims_X/WTAGarouWolf/Wolf_idle.glb", "Bip01_Tail")
check(idle_angles and abs(idle_angles[0] - 149.4) < 0.5, "Wolf_idle tail untouched (hangs straight down)")

# 0.4.82: Project Zomboid's Kahlua does NOT expose Lua's global next(). A
# bare next(table) call compiles (the headless lua5.1 tests have it) and then
# throws "Object tried to call nil" on every run in the game; the Oct 22
# hosted test lost lodged-silver burn growth and removal detection to one.
import re
bare_next = re.compile(r"(?<![\w_.:])next\s*\(")
for lua in sorted((root / "42/media/lua").rglob("*.lua")):
    offenders = []
    for n, line in enumerate(lua.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code = line.split("--", 1)[0]
        if bare_next.search(code):
            offenders.append(n)
    check(not offenders, f"{lua.relative_to(root).as_posix()} never calls Lua next() (Kahlua has none){' lines ' + str(offenders) if offenders else ''}")

# 0.4.19 / 0.4.83: InventoryItem.hasTag takes ItemTag objects in 42.20.2.
# hasTag("GasMask") throws "No implementation found for function:
# hasTag(Clothing, String)" - 46 times a second in the Oct 23 coop console,
# which is why a full gas mask did not keep silver smoke out. Compare tag
# names via getTags() + WTAGarou.Silver.tagKey instead. Only an ItemTag
# constant may be passed.
bad_has_tag = re.compile(r"hasTag\s*\(\s*(?!ItemTag\.)\S")
for lua in sorted((root / "42/media/lua").rglob("*.lua")):
    offenders = []
    for n, line in enumerate(lua.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        code = line.split("--", 1)[0]
        if bad_has_tag.search(code):
            offenders.append(n)
    check(not offenders, f"{lua.relative_to(root).as_posix()} never calls hasTag with anything but an ItemTag constant{' lines ' + str(offenders) if offenders else ''}")

# 0.4.83 Workshop package rules (zombie.core.znet.SteamWorkshopItem): no
# *.exe *.dll *.bat *.app *.dylib *.sh *.so *.zip in the shipped trees, a
# 256/512 square preview under 1,024,000 bytes, a workshop.txt with a
# known visibility, and a permission ledger for the third-party assets.
FORBIDDEN = (".exe", ".dll", ".bat", ".app", ".dylib", ".sh", ".so", ".zip")
for tree in ("42", "common"):
    bad = [p.relative_to(root).as_posix() for p in (root / tree).rglob("*") if p.is_file() and p.name.lower().endswith(FORBIDDEN)]
    check(not bad, f"{tree}/ has no file types the Workshop uploader refuses: {bad}")
preview = root / "workshop/preview.png"
check(preview.is_file() and preview.stat().st_size <= 1024000, "workshop/preview.png exists and is under 1,024,000 bytes")
pw, ph, _, _, _ = png_header(preview)
check(pw == ph and pw in (256, 512), f"workshop/preview.png is a 256 or 512 square: {pw}x{ph}")
wtxt = (root / "workshop/workshop.txt").read_text(encoding="utf-8")
check(re.search(r"^title=.+", wtxt, re.M) and re.search(r"^tags=.+", wtxt, re.M), "workshop.txt has a title and tags")
check(re.search(r"^visibility=(public|friendsOnly|private|unlisted)$", wtxt, re.M), "workshop.txt visibility is one the engine knows")
ledger = (root / "workshop/THIRD_PARTY_ASSETS.md").read_text(encoding="utf-8")
for group in ("wolfmod", "rabenrabo", "horsemod"):
    check(f"## Group: {group}" in ledger, f"third-party asset ledger covers {group}")
check((root / "tools/check_workshop_staging.py").is_file() and (root / "tools/stage_workshop.bat").is_file(), "Workshop staging script and checker exist")
# Access gate: the cheat surfaces never key on the dead B41 "None" level.
for lua in ("42/media/lua/server/WTAGarouServer.lua", "42/media/lua/shared/WTAGarouGrant.lua", "42/media/lua/client/WTAGarouTestPanel.lua"):
    text = (root / lua).read_text(encoding="utf-8")
    check('~= "None"' not in text and "~= \"none\"" not in text, f"{lua}: no '~= None' access gate (every B42 player is role 'user')")
    check("WTAGarou.Access.privileged" in text, f"{lua}: routes through WTAGarou.Access.privileged")

print(f"PASS: {checks} asset/reference/package assertions.")
