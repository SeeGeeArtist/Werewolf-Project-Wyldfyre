#!/bin/bash
#
# WTAGarou diagnose.sh
#
# Answers one question: WHERE is Project Zomboid actually loading WTAGarou
# from, and is it the copy you think it is?
#
# Every symptom in a "my edits did nothing" report comes down to this. Run it
# in Desktop Mode:
#
#     bash diagnose.sh
#
# It only reads. It changes nothing.

echo "=============================================="
echo " WTAGarou install diagnostic"
echo "=============================================="
echo

# ---------------------------------------------------------------------------
# 1. Every copy of the mod anywhere it could plausibly live.
# ---------------------------------------------------------------------------
echo "--- 1. Every mod.info with id=WTAGarou on this system ---"
echo

SEARCH_ROOTS=(
    "$HOME/Zomboid"
    "$HOME/.steam/steam/steamapps"
    "$HOME/.local/share/Steam/steamapps"
    "/run/media"
)

FOUND=0
for root in "${SEARCH_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    while IFS= read -r info; do
        if grep -qi "^id=WTAGarou" "$info" 2>/dev/null; then
            FOUND=$((FOUND + 1))
            ver=$(grep -i "^modversion=" "$info" | head -1 | cut -d= -f2 | tr -d '\r')
            echo "  [$FOUND] $info"
            echo "        modversion = ${ver:-<none>}"

            moddir=$(dirname "$info")
            defs=$(find "$moddir/.." -name "WTAGarouDefinitions.lua" 2>/dev/null | head -1)
            if [ -n "$defs" ]; then
                luaver=$(grep -o 'WTAGarou.VERSION = "[^"]*"' "$defs" | head -1 | cut -d'"' -f2)
                echo "        Definitions.lua VERSION = ${luaver:-<none>}"
            fi

            if find "$moddir/.." -name "registries.lua" 2>/dev/null | grep -q .; then
                echo "        registries.lua      = PRESENT (v0.3.x)"
            else
                echo "        registries.lua      = MISSING  (this is a pre-0.3 copy)"
            fi

            if find "$moddir/.." -name "WTAGarouVisual.lua" 2>/dev/null | grep -q .; then
                echo "        WTAGarouVisual.lua  = PRESENT (v0.3.x)"
            else
                echo "        WTAGarouVisual.lua  = MISSING  (this is a pre-0.3 copy)"
            fi
            echo
        fi
    done < <(find "$root" -name "mod.info" 2>/dev/null)
done

if [ "$FOUND" -eq 0 ]; then
    echo "  NONE FOUND. The mod is not installed anywhere this script looked."
    echo
elif [ "$FOUND" -gt 1 ]; then
    echo "  >>> $FOUND separate copies found."
    echo "  >>> This is almost certainly your problem. The game loads ONE of"
    echo "  >>> them, and it may not be the one you have been editing."
    echo
fi

# ---------------------------------------------------------------------------
# 2. Folder layout of the primary install.
# ---------------------------------------------------------------------------
echo "--- 2. Layout under ~/Zomboid/mods/WTAGarou ---"
echo
if [ -d "$HOME/Zomboid/mods/WTAGarou" ]; then
    find "$HOME/Zomboid/mods/WTAGarou" -maxdepth 2 \
        \( -type d -o -name "mod.info" \) | sed "s|$HOME|~|" | sort
else
    echo "  ~/Zomboid/mods/WTAGarou does not exist."
fi
echo

# ---------------------------------------------------------------------------
# 3. Nested-extraction check. Extracting a zip "here" twice produces
#    WTAGarou/WTAGarou/, which the game will not read.
# ---------------------------------------------------------------------------
echo "--- 3. Double-nesting check ---"
echo
if [ -d "$HOME/Zomboid/mods/WTAGarou/WTAGarou" ]; then
    echo "  PROBLEM: ~/Zomboid/mods/WTAGarou/WTAGarou/ exists."
    echo "  The zip was extracted one level too deep. Move the CONTENTS of the"
    echo "  inner folder up one level, then delete the empty inner folder."
else
    echo "  OK - no double-nested WTAGarou/WTAGarou/ folder."
fi
echo

# ---------------------------------------------------------------------------
# 4. What the log says the game actually loaded.
# ---------------------------------------------------------------------------
echo "--- 4. WTAGarou lines in console.txt ---"
echo
LOG="$HOME/Zomboid/console.txt"
if [ -f "$LOG" ]; then
    echo "  log last modified: $(date -r "$LOG" '+%Y-%m-%d %H:%M:%S')"
    echo
    if grep -q "WTAGarou" "$LOG"; then
        grep -n "WTAGarou" "$LOG" | tail -25 | sed 's/^/  /'
    else
        echo "  No WTAGarou lines at all. The mod never loaded."
    fi
    echo
    echo "  --- Lua errors near the end of the log ---"
    grep -niE "error|exception|cannot find|attempt to" "$LOG" | tail -15 | sed 's/^/  /'
else
    echo "  No console.txt at $LOG"
fi
echo

# ---------------------------------------------------------------------------
# 5. Is the mod actually enabled for the save you are loading?
# ---------------------------------------------------------------------------
echo "--- 5. Saves that list WTAGarou as enabled ---"
echo
if [ -d "$HOME/Zomboid/Saves" ]; then
    grep -rl "WTAGarou" "$HOME/Zomboid/Saves" 2>/dev/null \
        | head -10 | sed "s|$HOME|~|" | sed 's/^/  /'
    echo
    echo "  A save records its own mod list at creation. Enabling a mod in the"
    echo "  main menu does not always apply to an existing save."
else
    echo "  No Saves folder found."
fi
echo

echo "=============================================="
echo " Done. Paste this whole output back."
echo "=============================================="
