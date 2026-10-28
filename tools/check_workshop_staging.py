#!/usr/bin/env python3
"""Pre-upload check for the WTAGarou Steam Workshop item (0.4.83).

Usage:
    python3 tools/check_workshop_staging.py                 # check the repo tree
    python3 tools/check_workshop_staging.py <staged folder> # check Zomboid/Workshop/WTAGarou
    python3 tools/check_workshop_staging.py --public ...    # fail on pending asset permissions

Mirrors the engine's rules from zombie.core.znet.SteamWorkshopItem
(42.20.2): Contents/ may hold only mods/, buildings/, creative/ folders;
no *.exe *.dll *.bat *.app *.dylib *.sh *.so *.zip anywhere under Contents;
preview.png must be a 256 or 512 square PNG under 1,024,000 bytes;
workshop.txt needs title/description/tags/visibility. Then it reads
workshop/THIRD_PARTY_ASSETS.md: with --public every group must be
`granted` or `replaced`; without it pending groups are only listed.
Exit code 1 on any failure.
"""
import re
import struct
import sys
from pathlib import Path

FORBIDDEN = (".exe", ".dll", ".bat", ".app", ".dylib", ".sh", ".so", ".zip")
NOT_RUNTIME = (".md", ".py", ".psd", ".blend", ".blend1", ".dae")
VISIBILITY = ("public", "friendsOnly", "private", "unlisted")

fails, warns = [], []
def fail(msg): fails.append(msg); print("FAIL  " + msg)
def warn(msg): warns.append(msg); print("WARN  " + msg)
def ok(msg): print("ok    " + msg)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
public = "--public" in sys.argv
repo = Path(__file__).resolve().parent.parent
target = Path(args[0]).resolve() if args else None

if target:
    contents = target / "Contents"
    preview = target / "preview.png"
    wtxt = target / "workshop.txt"
    mod = contents / "mods" / "WTAGarou"
    if not contents.is_dir(): fail(f"missing {contents}")
    else:
        for p in contents.iterdir():
            if not p.is_dir(): fail(f"file not allowed directly in Contents: {p.name}")
            elif p.name not in ("mods", "buildings", "creative"): fail(f"folder not allowed in Contents: {p.name}")
        mods = contents / "mods"
        if mods.is_dir() and not any(x.is_dir() for x in mods.iterdir()): fail("Contents/mods is empty")
else:
    preview = repo / "workshop" / "preview.png"
    wtxt = repo / "workshop" / "workshop.txt"
    mod = repo
    ok(f"checking the repository tree {repo} (not a staged folder)")

# Runtime tree ----------------------------------------------------------------
trees = [mod / "42", mod / "common"]
for t in trees:
    if not t.is_dir(): fail(f"missing {t}"); continue
    for p in t.rglob("*"):
        if p.is_dir(): continue
        low = p.name.lower()
        if low.endswith(FORBIDDEN): fail(f"engine refuses this file type: {p.relative_to(mod)}")
        if low.endswith(NOT_RUNTIME): warn(f"not a runtime file, exclude from the upload: {p.relative_to(mod)}")
        if p.name in ("poster - full.png", "world-on-fire-glyph.png"): warn(f"unused source art, exclude: {p.relative_to(mod)}")
info = mod / "42" / "mod.info"
if not info.is_file(): fail("42/mod.info missing")
else:
    text = info.read_text(encoding="utf-8", errors="replace")
    fields = dict(re.findall(r"^(\w+)=(.*)$", text, re.M))
    for k in ("name", "id", "modversion", "versionMin", "require", "javaJarFile", "poster", "icon"):
        if not fields.get(k): fail(f"mod.info lacks {k}=")
    if fields.get("id") != "WTAGarou": fail(f"mod.info id is {fields.get('id')!r}, expected WTAGarou")
    if fields.get("require") != "\\ZombieBuddy": warn(f"mod.info require is {fields.get('require')!r}")
    for k in ("poster", "icon", "javaJarFile"):
        if fields.get(k) and not (mod / "42" / fields[k]).is_file(): fail(f"mod.info {k}={fields[k]} does not exist")
    defs = mod / "42" / "media" / "lua" / "shared" / "WTAGarouDefinitions.lua"
    m = re.search(r'WTAGarou\.VERSION\s*=\s*"([^"]+)"', defs.read_text(encoding="utf-8")) if defs.is_file() else None
    if m and m.group(1) != fields.get("modversion"): fail(f"modversion {fields.get('modversion')} != WTAGarou.VERSION {m.group(1)}")
    elif m: ok(f"version {m.group(1)} in mod.info and Definitions")

# preview.png -----------------------------------------------------------------
if not preview.is_file(): fail(f"preview.png missing at {preview}")
else:
    data = preview.read_bytes()
    if len(data) > 1024000: fail(f"preview.png is {len(data)} bytes (limit 1,024,000)")
    if data[:8] != b"\x89PNG\r\n\x1a\n": fail("preview.png is not a PNG")
    else:
        w, h = struct.unpack(">II", data[16:24])
        if w != h or w not in (256, 512): fail(f"preview.png must be a 256 or 512 square, got {w}x{h}")
        else: ok(f"preview.png {w}x{h}, {len(data)} bytes")

# ZombieBuddy signature --------------------------------------------------------
# <jar>.zbs next to the jar, verified exactly as ZBSVerifier does, with the
# public key committed in workshop/ZBS_PUBLIC_KEY.txt. Stale = tampered.
sys.path.insert(0, str(repo / "tools"))
try:
    import sign_jar_zbs as _zbs
    jar = (target if target else repo) / "42" / "media" / "java" / "client" / "WTAGarouVisuals.jar"
    pub = repo / "workshop" / "ZBS_PUBLIC_KEY.txt"
    if not pub.is_file():
        warn("no workshop/ZBS_PUBLIC_KEY.txt: jar ships UNSIGNED (ZombieBuddy asks every user to approve; run tools/sign_jar_zbs.py keygen + sign)")
    elif not jar.is_file():
        warn(f"jar missing at {jar}")
    else:
        okz, msg = _zbs.verify_sidecar(jar, pub.read_text().strip())
        (ok if okz else fail)("ZBS " + msg)
except Exception as e:  # never let the signer break the checker
    warn(f"ZBS check skipped: {e}")

# Steam page text ------------------------------------------------------------
page = repo / "workshop" / "STEAM_PAGE.bbcode.txt"
if page.is_file():
    n = len(page.read_text(encoding="utf-8"))
    if n > 8000: fail(f"STEAM_PAGE.bbcode.txt is {n} characters; Steam cuts Workshop descriptions at 8,000")
    else: ok(f"STEAM_PAGE.bbcode.txt {n}/8000 characters")
else: warn("workshop/STEAM_PAGE.bbcode.txt missing (paste-ready page text)")

# workshop.txt ----------------------------------------------------------------
if not wtxt.is_file(): fail(f"workshop.txt missing at {wtxt}")
else:
    lines = [l for l in wtxt.read_text(encoding="utf-8").splitlines() if l and not l.startswith(("#", "//"))]
    kv = {}
    for l in lines:
        k, _, v = l.partition("=")
        kv.setdefault(k, []).append(v)
    if not kv.get("title", [""])[0]: fail("workshop.txt: title= is empty")
    if not any(kv.get("description", [])): fail("workshop.txt: no description= line")
    if not kv.get("tags", [""])[0]: fail("workshop.txt: tags= is empty")
    vis = kv.get("visibility", [""])[0]
    if vis not in VISIBILITY: fail(f"workshop.txt: visibility must be one of {VISIBILITY}, got {vis!r}")
    else: ok(f"workshop.txt visibility={vis}")
    if public and vis != "public": warn("--public given but workshop.txt visibility is not public")
    wid = kv.get("id", [""])[0]
    ok("workshop.txt id=" + (wid or "<unset: first upload assigns it; keep the file afterwards>"))

# Third-party asset ledger ----------------------------------------------------
ledger = repo / "workshop" / "THIRD_PARTY_ASSETS.md"
if not ledger.is_file(): fail("workshop/THIRD_PARTY_ASSETS.md missing")
else:
    groups = re.findall(r"^## Group: (\S+).*?^- STATUS: (\S+)", ledger.read_text(encoding="utf-8"), re.M | re.S)
    if not groups: fail("ledger has no '## Group:' / '- STATUS:' entries")
    for name, status in groups:
        if status in ("granted", "replaced"): ok(f"assets {name}: {status}")
        elif public: fail(f"assets {name}: permission {status} - a public upload redistributes them without permission")
        else: warn(f"assets {name}: permission {status} (blocks a public upload)")

print()
print(f"{len(fails)} failure(s), {len(warns)} warning(s)")
sys.exit(1 if fails else 0)
