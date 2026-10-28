#!/usr/bin/env bash
# WTAGarou - stage the Steam Workshop item folder on Linux / Steam Deck.
# Same result as tools/stage_workshop.bat on Windows.
#
#   bash tools/stage_workshop.sh              # stage into ~/Zomboid/Workshop/WTAGarou
#   bash tools/stage_workshop.sh --id 3828594567   # also write the item id into workshop.txt
#
# Then in the game: Main menu > Workshop > WTAGarou > Update item.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${ZOMBOID_HOME:-$HOME/Zomboid}/Workshop/WTAGarou"
MOD="$DEST/Contents/mods/WTAGarou"
ID=""
while [ $# -gt 0 ]; do
    case "$1" in
        --id) ID="$2"; shift 2 ;;
        *) echo "unknown option $1"; exit 2 ;;
    esac
done

echo "Staging $HERE -> $DEST"
rm -rf "$DEST/Contents"
mkdir -p "$MOD"
EXCL=(--exclude='*.base.glb' --exclude='*.md' --exclude='*.bat' --exclude='*.sh' --exclude='*.py'
      --exclude='*.zip' --exclude='*.psd' --exclude='*.blend' --exclude='*.blend1'
      --exclude='Thumbs.db' --exclude='.DS_Store' --exclude='.git' --exclude='__pycache__')
rsync -a --delete "${EXCL[@]}" --exclude='poster - full.png' --exclude='world-on-fire-glyph.png' "$HERE/42/" "$MOD/42/"
rsync -a --delete "${EXCL[@]}" "$HERE/common/" "$MOD/common/"
cp -f "$HERE/workshop/preview.png" "$DEST/preview.png"

# workshop.txt: keep an existing file that already has an id; otherwise take the repo copy.
if [ ! -f "$DEST/workshop.txt" ] || grep -qx 'id=' "$DEST/workshop.txt"; then
    cp -f "$HERE/workshop/workshop.txt" "$DEST/workshop.txt"
fi
if [ -n "$ID" ]; then
    sed -i "s/^id=.*/id=$ID/" "$DEST/workshop.txt"
fi

echo
echo "workshop.txt id line:"
grep '^id=' "$DEST/workshop.txt" || true
if grep -qx 'id=' "$DEST/workshop.txt"; then
    echo "  WARNING: id is empty. Uploading now would CREATE A SECOND Workshop item."
    echo "  Re-run with --id <published item id> to update the existing one."
fi

echo
echo "Forbidden file types under Contents (must print nothing):"
find "$DEST/Contents" -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.bat' -o -name '*.app' \
     -o -name '*.dylib' -o -name '*.sh' -o -name '*.so' -o -name '*.zip' \) -print

echo
echo "mod.info:"
grep -E '^(id|modversion|versionMin|require|javaJarFile)=' "$MOD/42/mod.info"

JAR="$MOD/42/media/java/client/WTAGarouVisuals.jar"
echo
echo "Java supplement SHA-256:"
sha256sum "$JAR" | cut -d' ' -f1

echo
if [ -f "$JAR.zbs" ]; then
    if [ -f "$HERE/workshop/ZBS_PUBLIC_KEY.txt" ] && command -v python3 >/dev/null; then
        python3 "$HERE/tools/sign_jar_zbs.py" verify --jar "$JAR" || {
            echo "  The staged signature does not match the staged jar. Run: python3 tools/sign_jar_zbs.py sign"; exit 1; }
    else
        echo "ZBS sidecar staged (not verified here: no workshop/ZBS_PUBLIC_KEY.txt)."
    fi
else
    echo "No ZBS sidecar: the jar ships unsigned (ZombieBuddy asks each player to approve it)."
    echo "  To sign: python3 tools/sign_jar_zbs.py sign   (then re-run this script)"
fi

echo
echo "Staged. Open Project Zomboid: Main menu > Workshop > WTAGarou > Update item."
