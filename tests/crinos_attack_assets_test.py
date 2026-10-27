#!/usr/bin/env python3
"""Native graph contract; not in-game animation proof."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
# 0.4.70: the attack-button shove runs through the "shoveAim" state
# (isShovingWhileAiming), so the node must exist in both state folders and
# be identical apart from the comment.
def strip_comments(text):
    import re
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)
shove_xml = (root / "42/media/AnimSets/player/shove/WTAGarouCrinosClaw.xml").read_text()
aim_xml = (root / "42/media/AnimSets/player/shoveAim/WTAGarouCrinosClaw.xml").read_text()
assert strip_comments(shove_xml) == strip_comments(aim_xml), "shove and shoveAim Crinos claw nodes differ"
assert "shoveAim" in aim_xml
node = ET.parse(root / "42/media/AnimSets/player/shoveAim/WTAGarouCrinosClaw.xml").getroot()
assert node.tag == "animNode"
assert node.findtext("m_AnimName") == "Bob_Attack1Hand01_Hit"
assert int(node.findtext("m_ConditionPriority")) > 0
assert node.findtext("m_Looped") == "false"
conditions = {c.findtext("m_Name"): c.findtext("m_BoolValue") for c in node.findall("m_Conditions")}
assert conditions == {"WTAGarouCrinosUnarmed": "true", "WTAGarouCrinosSwing": "true", "AimFloorAnim": "false"}
events = node.findall("m_Events")
collisions = [e for e in events if e.findtext("m_EventName") == "AttackCollisionCheck"]
assert len(collisions) == 1 and collisions[0].findtext("m_TimePc") == "0.25"
assert not any(e.findtext("m_EventName") in {"AttackAnim", "PlaySound", "PlaySwingSound"} for e in events)
shove = {e.findtext("m_Time"): e.findtext("m_ParameterValue")
         for e in events if e.findtext("m_EventName") == "ShoveAnim"}
assert shove == {"Start": "TRUE", "End": "FALSE"}
assert any(e.findtext("m_EventName") == "SetMeleeDelay" and e.findtext("m_ParameterValue") == "8" for e in events)
assert any(e.findtext("m_EventName") == "BlockMovement" and e.findtext("m_Time") == "End"
           and e.findtext("m_ParameterValue") == "FALSE" for e in events)
assert node.findall("m_SubStateBoneWeights")
visual = (root / "42/media/lua/client/WTAGarouVisual.lua").read_text()
assert 'require "WTAGarouCrinosAttack"' in visual
assert "WTAGarou.CrinosAttack.refresh(player, form)" in visual
assert "WTAGarou.CrinosAttack.clear(player)" in visual
conds = {c.findtext("m_Name"): c.findtext("m_BoolValue") for c in node.findall("m_Conditions")}
assert conds.get("WTAGarouCrinosUnarmed") == "true" and conds.get("WTAGarouCrinosSwing") == "true" \
    and conds.get("AimFloorAnim") == "false", conds  # 0.4.69: attack button only
java = (root / "java/src/wtagarou/visuals/CrinosSwingRuntime.java").read_text()
assert 'SWING_VARIABLE="WTAGarouCrinosSwing"' in java and '"isMeleePressed"' in java and '"isAttackStarted"' in java
patch = (root / "java/src/wtagarou/visuals/CrinosSwingPatch.java").read_text()
assert 'className="zombie.characters.IsoPlayer", methodName="pressedAttack"' in patch
lua = (root / "42/media/lua/client/WTAGarouCrinosAttack.lua").read_text()
assert 'Attack.swinging(player)' in lua and 'SWING_VARIABLE = "WTAGarouCrinosSwing"' in lua
print("PASS: Crinos swing node (shove + shoveAim states) is standing/unarmed/attack-button-only, one collision, native shove flags, no miss audio.")
