#!/usr/bin/env python3
"""Generate the explicit coatable / forgeable weapon lists for silver_recipes.txt.

0.4.65: hosted co-op servers run without ZombieBuddy, so CoatableTagRuntime
never tags the vanilla weapons there and a recipe input written as
`tags[wtagarou:coatable]` is fatal ("Tag has no items" aborts world load).
The recipes therefore carry explicit item lists. This script derives them
from the vanilla item scripts with the same rule as
CoatableTagRuntime.decide / forgeable, so the two stay in step.

The coat recipe's weapon slot is the explicit list PLUS the vanilla metal
tags (InputScript unions `[items]` and `tags[...]`), so metal weapons added
after the list was generated still qualify; OnTestCoatInput refuses the
non-weapon metal junk the tags drag in. The forge recipe's weapon slot is
the explicit forgeable list only: a tag union would put hammers back into
the weapon slot, which 0.4.63 deliberately removed.

Usage:
    python3 gen_coatable_lists.py <path to media/scripts> [--write] [--extra Base.X;Base.Y]

--extra adds script names the reference scripts lack (e.g. weapons the
client's drift report listed). Without --write it prints the lists; with
--write it rewrites the two marked `item 1 ...` lines in
../42/media/scripts/silver_recipes.txt in place.
"""
import os
import re
import sys

FORGE_TOOL_TAGS = {"tongs", "file", "hammer", "clubhammer"}
METAL_BY_NAME = {"carvingfork2", "iceaxe"}
HERE = os.path.dirname(os.path.abspath(__file__))
RECIPES = os.path.normpath(os.path.join(HERE, "..", "42", "media", "scripts", "silver_recipes.txt"))


def strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


def blocks(text, keyword):
    """Yield (name, body) for every top-level `keyword Name { ... }` with brace matching."""
    for m in re.finditer(r"\b%s\s+([^\s{]+)\s*\{" % keyword, text):
        depth, i = 1, m.end()
        while i < len(text) and depth:
            depth += {"{": 1, "}": -1}.get(text[i], 0)
            i += 1
        yield m.group(1), text[m.end():i - 1]


def params(body):
    out = {}
    for line in body.split(","):
        if "=" in line and "{" not in line.split("=", 1)[0]:
            k, v = line.split("=", 1)
            out[k.strip().lower()] = v.strip()
    return out


def decide(p, name):
    if p.get("type", "").lower() != "weapon":
        return 0
    if p.get("ranged", "").lower() == "true":
        return 0
    tags = {t.strip().lower() for t in p.get("tags", "").split(";") if t.strip()}
    try:
        metal = float(p.get("metalvalue", "0") or 0) > 0
    except ValueError:
        metal = False
    metal = metal or name.lower() in METAL_BY_NAME
    metal = metal or any(t == "hasmetal" or t == "sharpenable" or t.startswith("smeltable") for t in tags)
    if not metal:
        return 0
    if p.get("displaycategory", "").lower() == "material":
        return 0
    if "silver" in name.lower() or "silver" in p.get("displayname", "").lower():
        return 0
    return 1 if tags & FORGE_TOOL_TAGS else 2


def scan(root):
    coat, forge = [], []
    for dirpath, _, files in os.walk(root):
        for f in sorted(files):
            if not f.endswith(".txt"):
                continue
            with open(os.path.join(dirpath, f), encoding="utf-8", errors="replace") as fh:
                text = strip_comments(fh.read())
            for module, mbody in blocks(text, "module"):
                for name, body in blocks(mbody, "item"):
                    level = decide(params(body), name)
                    if level:
                        full = f"{module}.{name}"
                        coat.append(full)
                        if level == 2:
                            forge.append(full)
    return sorted(set(coat)), sorted(set(forge))


METAL_TAGS = ["HasMetal", "Sharpenable",
              "SmeltableIronSmall", "SmeltableIronMedium", "SmeltableIronMediumPlus", "SmeltableIronLarge",
              "SmeltableSteelSmall", "SmeltableSteelMedium", "SmeltableSteelMediumPlus", "SmeltableSteelLarge"]


def coat_line(coat):
    return "item 1 [" + ";".join(coat) + "] tags[" + ";".join(METAL_TAGS) + "] mode:keep,"


def forge_line(forge):
    return "item 1 [" + ";".join(forge) + "] mode:keep,"


def rewrite(coat, forge):
    with open(RECIPES, encoding="utf-8") as fh:
        text = fh.read()

    def repl(marker, line):
        nonlocal text
        pat = re.compile(r"(/\* %s \*/\n\s*)item 1 [^\n]*" % re.escape(marker))
        new, n = pat.subn(lambda m: m.group(1) + line, text, count=1)
        if n != 1:
            raise SystemExit(f"marker {marker!r} not found in {RECIPES}")
        text = new
    repl("GENERATED forgeable list: tools/gen_coatable_lists.py", forge_line(forge))
    repl("GENERATED coatable list: tools/gen_coatable_lists.py", coat_line(coat))
    with open(RECIPES, "w", encoding="utf-8") as fh:
        fh.write(text)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    coat, forge = scan(sys.argv[1])
    if "--extra" in sys.argv:
        for name in sys.argv[sys.argv.index("--extra") + 1].split(";"):
            name = name.strip()
            if name and name not in coat:
                coat.append(name)
                forge.append(name)
        coat, forge = sorted(set(coat)), sorted(set(forge))
    print(f"coatable: {len(coat)}  forgeable: {len(forge)}")
    if "--write" in sys.argv:
        rewrite(coat, forge)
        print("wrote", RECIPES)
    else:
        print(coat_line(coat))
        print(forge_line(forge))
