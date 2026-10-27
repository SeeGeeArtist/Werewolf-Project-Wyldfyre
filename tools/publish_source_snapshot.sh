#!/usr/bin/env bash
# Publish the WTAGarou tree as a source snapshot to the public repository
# github.com/SeeGeeArtist/Werewolf-Project-Wyldfyre.
#
# Snapshots, not history: the private Zomboid-Garou repository tracks copies
# of other people's mods and has a licensed Epidemic Sound WAV in its
# history, so its history is never pushed anywhere public. Each release
# becomes one commit over here, labelled with the version and the private
# commit it came from, which is all a reader needs to rebuild the JAR and
# compare hashes.
#
# Usage: tools/publish_source_snapshot.sh [--public-check] [--reset-history]
#   --public-check   refuse unless tools/check_workshop_staging.py --public passes
#   --reset-history  publish this snapshot as the ONLY commit (orphan main,
#                    old tags deleted). Needed once before the repository
#                    goes public: the 0.4.83-0.4.89 snapshots carried the
#                    Earthblood/Epidemic audio and the RabenRabo/Horse Mod
#                    meshes that were later replaced, and a public history
#                    would republish them. Safe while nobody else has cloned.
set -euo pipefail
RESET=0
for arg in "$@"; do [ "$arg" = "--reset-history" ] && RESET=1; done
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PUB_REMOTE="${PUB_REMOTE:-https://github.com/SeeGeeArtist/Werewolf-Project-Wyldfyre.git}"
WORK="${WORK:-/tmp/wyldfyre-public}"
VERSION="$(sed -n 's/^modversion=//p' "$HERE/42/mod.info")"
SRC_COMMIT="$(git -C "$HERE" rev-parse --short HEAD)"
SRC_DIRTY="$(git -C "$HERE" status --porcelain -- . | wc -l)"
if [ "$SRC_DIRTY" != "0" ]; then echo "working tree has uncommitted changes; commit first" >&2; exit 1; fi
for arg in "$@"; do [ "$arg" = "--public-check" ] && python3 "$HERE/tools/check_workshop_staging.py" --public; done

rm -rf "$WORK"
git clone -q "$PUB_REMOTE" "$WORK" 2>/dev/null || { mkdir -p "$WORK"; git -C "$WORK" init -q -b main; git -C "$WORK" remote add origin "$PUB_REMOTE"; }
# wipe everything but .git, then copy the tracked files of WTAGarou/
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
git -C "$HERE" ls-files -z | while IFS= read -r -d '' f; do
    case "$f" in README_PUBLIC.md|*.psd|*.wav) continue ;; esac
    mkdir -p "$WORK/$(dirname "$f")"; cp "$HERE/$f" "$WORK/$f"
done
[ -f "$HERE/README_PUBLIC.md" ] && cp "$HERE/README_PUBLIC.md" "$WORK/README.md"
cat > "$WORK/.gitignore" <<'G'
*.psd
java/build/
__pycache__/
G
JAR_SHA="$(sha256sum "$HERE/42/media/java/client/WTAGarouVisuals.jar" | cut -c1-64)"
if [ "$RESET" = "1" ]; then
    OLD_TAGS="$(git -C "$WORK" tag -l)"
    git -C "$WORK" checkout -q --orphan clean-main
    git -C "$WORK" branch -D main >/dev/null 2>&1 || true
    git -C "$WORK" branch -M main
fi
git -C "$WORK" add -A
git -C "$WORK" -c user.name="SeeGeeArtist" -c user.email="ludechris31@gmail.com" commit -q -m "Source snapshot $VERSION (Zomboid-Garou $SRC_COMMIT)

WTAGarouVisuals.jar sha256 $JAR_SHA
Rebuild: cd java && bash build.sh" || { echo "nothing changed since the last snapshot"; exit 0; }
git -C "$WORK" tag -f "v$VERSION" >/dev/null
if [ "$RESET" = "1" ]; then
    for t in $OLD_TAGS; do [ "$t" = "v$VERSION" ] || git -C "$WORK" push -q origin ":refs/tags/$t" || true; git -C "$WORK" tag -d "$t" >/dev/null 2>&1 || true; done
    git -C "$WORK" tag -f "v$VERSION" >/dev/null
    git -C "$WORK" push -q -f origin main && git -C "$WORK" push -q -f origin "refs/tags/v$VERSION"
    echo "history reset: main is now the single commit $(git -C "$WORK" rev-parse --short HEAD)"
else
    git -C "$WORK" push -q origin main && git -C "$WORK" push -q -f origin "refs/tags/v$VERSION"
fi
echo "pushed snapshot $VERSION ($SRC_COMMIT) to $PUB_REMOTE; jar sha256 $JAR_SHA"
