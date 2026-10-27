#!/usr/bin/env python3
"""
map_wolf_anims.py - Option A from docs/ANIMATION_MAPPING.md

Copies the wolf animation clips to the human clip names the player's AnimSet
requests, so a player wearing the wolf model animates instead of standing in
bind pose.

Run it on the Steam Deck in Desktop Mode:

    python3 tools/map_wolf_anims.py --dry-run
    python3 tools/map_wolf_anims.py

By default it works on the installed mod at
~/Zomboid/mods/WTAGarou/common/media/anims_X/WTAGarouWolf/ and copies rather
than renames, so the originals stay put and you can re-run it freely.

If you pass --scan-animsets pointing at your Project Zomboid install, it will
also read the vanilla AnimSet XML files and report every human clip the state
machine asks for that has no wolf equivalent. That list is your to-do list if
you decide the prototype is worth finishing.
"""

import argparse
import os
import re
import shutil
import sys

# Wolf clip -> the human clip names the player AnimSet asks for.
# One wolf clip can serve several human names; that is the point.
MAPPING = {
    "Wolf_idle": [
        "Bob_Idle",
        "Bob_Idle01",
        "Bob_IdleTurn",
    ],
    "Wolf_walk": [
        "Bob_Walk",
        "Bob_WalkAim",
        "Bob_Sneak",
        "Bob_SneakWalk",
    ],
    "Wolf_run": [
        "Bob_Run",
        "Bob_RunAim",
    ],
    "Wolf_run_V2": [
        "Bob_Sprint",
    ],
    "Wolf_attack": [
        "Bob_AttackUnarmed",
        "Bob_Shove",
    ],
    "Wolf_hitreaction": [
        "Bob_HitReaction",
        "Bob_HitReactionFront",
    ],
    "Wolf_death": [
        "Bob_Death",
    ],
    "Wolf_dead": [
        "Bob_Dead",
        "Bob_DeadOnGround",
    ],
    "Wolf_eat": [
        "Bob_Eat",
    ],
    "Wolf_Sit": [
        "Bob_SitOnGround",
        "Bob_SitOnGroundIdle",
    ],
}

DEFAULT_ANIM_DIR = os.path.expanduser(
    "~/Zomboid/mods/WTAGarou/common/media/anims_X/WTAGarouWolf"
)


def copy_clips(anim_dir, dry_run):
    if not os.path.isdir(anim_dir):
        sys.exit("animation directory not found: %s" % anim_dir)

    made, missing = 0, []
    for wolf_clip, human_names in MAPPING.items():
        src = os.path.join(anim_dir, wolf_clip + ".glb")
        if not os.path.isfile(src):
            missing.append(wolf_clip)
            continue
        for human in human_names:
            dst = os.path.join(anim_dir, human + ".glb")
            if os.path.exists(dst):
                print("  skip (exists)  %s" % os.path.basename(dst))
                continue
            print("  %s -> %s" % (os.path.basename(src), os.path.basename(dst)))
            if not dry_run:
                shutil.copy2(src, dst)
            made += 1

    print("\n%d clip copies %s" % (made, "planned" if dry_run else "written"))
    if missing:
        print("wolf clips not found: %s" % ", ".join(sorted(missing)))

    print(
        "\nReminder: remove the `animationPrefix = Wolf_` line from the\n"
        "`animationsMesh WTAGarou_Wolf` block in\n"
        "42/media/scripts/wtagarou_models.txt, or the engine will look for\n"
        "Wolf_Bob_Walk instead of Bob_Walk."
    )


ANIM_NAME_RE = re.compile(r'm_AnimName\s*[>=]\s*["\']?([A-Za-z0-9_]+)', re.I)


def scan_animsets(animset_root, anim_dir):
    """Report human clip names the AnimSets request that we have no clip for."""
    if not os.path.isdir(animset_root):
        sys.exit("AnimSet directory not found: %s" % animset_root)

    requested = set()
    for dirpath, _dirs, files in os.walk(animset_root):
        for name in files:
            if not name.lower().endswith((".xml", ".txt")):
                continue
            path = os.path.join(dirpath, name)
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                    for match in ANIM_NAME_RE.finditer(fh.read()):
                        requested.add(match.group(1))
            except OSError:
                continue

    have = {
        os.path.splitext(f)[0]
        for f in os.listdir(anim_dir)
        if f.lower().endswith(".glb")
    }

    unmapped = sorted(requested - have)
    print("\nAnimSet requests %d distinct clips." % len(requested))
    print("%d of them have no wolf clip:\n" % len(unmapped))
    for name in unmapped:
        print("  " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--anim-dir", default=DEFAULT_ANIM_DIR,
                        help="WTAGarouWolf animation folder")
    parser.add_argument("--dry-run", action="store_true",
                        help="print what would happen, change nothing")
    parser.add_argument("--scan-animsets", metavar="PATH", default=None,
                        help="path to the game's media/AnimSets/ folder")
    args = parser.parse_args()

    print("animation dir: %s" % args.anim_dir)
    copy_clips(args.anim_dir, args.dry_run)

    if args.scan_animsets:
        scan_animsets(args.scan_animsets, args.anim_dir)


if __name__ == "__main__":
    main()
