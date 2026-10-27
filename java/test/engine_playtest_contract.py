"""Private engine surface/order checks, no game code redistributed."""
import os
import re
import subprocess
import sys


def bytecode(name):
    return subprocess.check_output(
        [os.environ.get("JAVAP_GAME", "javap"), "-p", "-c", "-classpath", sys.argv[1], name],
        text=True,
    )


def method(text, declaration):
    assert declaration in text, f"Missing engine surface: {declaration}"
    return re.split(r"\n  (?:public|private|protected|static) ",
                    text.split(declaration, 1)[1], maxsplit=1)[0]


ap = bytecode("zombie.core.skinnedmodel.animation.AnimationPlayer")
standard = method(ap, "private void updateAnimation_StandardAnimation(float);")
assert standard.index("Method updateMultiTrackBoneTransforms:") < standard.index("Method updateTwistBone:")
assert standard.index("Method updateTwistBone:") < standard.index("Method updateModelTransforms:")
assert standard.index("Method updateModelTransforms:") < standard.index("Method UpdateSkinTransforms:")
sample = method(ap, "private void updateMultiTrackBoneTransformsInternal(float);")
assert "AnimatorsBoneTransform.nextFrame:" in sample and "Method updateBoneAnimationTransform:" in sample
apply = method(ap, "private void applyTwistBone(zombie.core.skinnedmodel.model.SkinningBone, org.lwjgl.util.vector.Quaternion);")
assert "SkinningBone.parent:" in apply and "Matrix4f.invert:" in apply
assert "HelperFunctions.getPosition:" in apply and "HelperFunctions.setPosition:" in apply
assert "AnimatorsBoneTransform.mul:" in apply
character = bytecode("zombie.characters.IsoGameCharacter")
for signature in ["public boolean isSittingOnFurniture();", "public boolean isHeadLookAround();",
                  "public float getHeadLookHorizontal();", "public float getHeadLookAngleMax();"]:
    assert signature in character
head_set = method(character, "public void setHeadLookAroundDirection(float, float);")
assert "headLookHorizontal:F" in head_set and "PZMath.clamp:" in head_set
player = bytecode("zombie.characters.IsoPlayer")
assert "Method isAnyAimKeyDown:()Z" in player
assert "Method getHeadLookAngleMax:()F" in player
assert "Method setHeadLookAroundDirection:(FF)V" in player
skin = bytecode("zombie.core.skinnedmodel.model.SkinningData")
assert "public zombie.core.skinnedmodel.model.SkinningBone getBone(java.lang.String);" in skin
swipe = method(bytecode("zombie.ai.states.SwipeStatePlayer"),
               "public void enter(zombie.characters.IsoGameCharacter);")
assert swipe.index("Method zombie/CombatManager.calculateAttackVars:") < swipe.index("String OnWeaponSwing")
assert "AttackVars.doGrapple:Z" in swipe
wrapper = bytecode("zombie.core.skinnedmodel.IGrappleableWrapper")
assert "public default boolean isDoGrapple();" in wrapper
assert "public default boolean isPerformingGrappleGrabAnimation();" in wrapper
assert "public java.lang.String getName();" in bytecode("zombie.ai.State")
dragging = bytecode("zombie.ai.states.PlayerDraggingCorpse")
assert "public void enter(zombie.characters.IsoGameCharacter);" in dragging
# 0.4.39 bulk forms: vehicle entry gate, window climb, bare-handed smash surfaces.
vehicle = bytecode("zombie.vehicles.BaseVehicle")
for signature in ["public boolean isEnterBlocked(zombie.characters.IsoGameCharacter, int);",
                  "public boolean exit(zombie.characters.IsoGameCharacter);",
                  "public int getSeat(zombie.characters.IsoGameCharacter);",
                  "public zombie.vehicles.VehiclePart getPassengerDoor(int);",
                  "public void transmitPartCondition(zombie.vehicles.VehiclePart);"]:
    assert signature in vehicle, signature
part = bytecode("zombie.vehicles.VehiclePart")
for signature in ["public void damage(int);", "public zombie.vehicles.VehicleWindow getWindow();",
                  "public zombie.vehicles.VehiclePart getChildWindow();", "public zombie.vehicles.VehicleWindow findWindow();"]:
    assert signature in part, signature
glass = bytecode("zombie.vehicles.VehicleWindow")
assert "public void hit(zombie.characters.IsoGameCharacter);" in glass
assert "public void damage(int);" in glass and "public boolean isDestroyed();" in glass
assert "String VehicleWindowSmash" in glass and "Method zombie/WorldSoundManager.addSound:" in glass
assert "public void climbThroughWindow(zombie.iso.objects.IsoWindow);" in character
climb = method(character, "public void climbThroughWindow(zombie.iso.objects.IsoWindow);")
assert "Method zombie/iso/objects/IsoWindow.canClimbThrough:" in climb
window = bytecode("zombie.iso.objects.IsoWindow")
for signature in ["public void WeaponHit(zombie.characters.IsoGameCharacter, zombie.inventory.types.HandWeapon);",
                  "public boolean isSmashed();", "public boolean isDestroyed();", "public boolean isBarricaded();",
                  "public void smashWindow();"]:
    assert signature in window, signature
assert "public zombie.characters.BodyDamage.BodyPart setScratchedWindow();" in bytecode("zombie.characters.BodyDamage.BodyDamage")
smash = bytecode("zombie.ai.states.SmashWindowState")
assert "Method zombie/iso/objects/IsoWindow.WeaponHit:" in smash and "Method zombie/vehicles/VehicleWindow.hit:" in smash
assert smash.index("BodyDamage.setScratchedWindow:") < smash.index("String PainFromGlassCut")
print("PASS: B42 bulk-form vehicle/window surfaces (isEnterBlocked, exit, door/window parts, WeaponHit, bare-handed cut).")
print("PASS: B42 pose-sample/head-pivot/palette order, normalized head input and grapple-swing surfaces.")

# 0.4.40 wolf corpse handling: grapple offset funnel, dragging/grapple flags,
# corpse <-> item surfaces used by the Crinos/Hispo stow option.
grappleable = bytecode("zombie.core.skinnedmodel.BaseGrappleable")
assert "public void setGrapplePosOffsetForward(float);" in grappleable
assert "private zombie.characters.IsoGameCharacter character;" in grappleable
assert "public boolean isGrappling();" in grappleable
anim_layer = bytecode("zombie.core.skinnedmodel.advancedanimation.AnimLayer")
assert "LiveAnimNode.getGrappleOffsetForward:()F" in anim_layer
assert "IGrappleable.setGrapplePosOffsetForward:(F)V" in anim_layer
assert "public default boolean isGrappling();" in wrapper  # inherited default (Class.getMethod finds it)
for signature in ["public boolean isGrappleThrowIntoContainer();",
                  "public void pickUpCorpseItem(zombie.inventory.InventoryItem);",
                  "public void throwGrappledIntoInventory(zombie.inventory.ItemContainer);"]:
    assert signature in character, signature
dead_body = bytecode("zombie.iso.objects.IsoDeadBody")
assert "public zombie.inventory.InventoryItem becomeCorpseItem(boolean);" in dead_body
assert "public zombie.inventory.InventoryItem getItem();" in dead_body
become = method(dead_body, "public zombie.inventory.InventoryItem becomeCorpseItem(boolean);")
assert "IsoGridSquare.removeCorpse:" in become
square = bytecode("zombie.iso.IsoGridSquare")
assert "public zombie.iso.objects.IsoDeadBody tryAddCorpseToWorld(zombie.inventory.InventoryItem, float, float, boolean);" in square
# File-clip volume: the engine never sets a volume on the non-bank channel group.
sound_manager = bytecode("zombie.SoundManager")
assert "FMODManager.channelGroupInGameNonBankSounds:J" in sound_manager
assert "FMOD_ChannelGroup_SetVolume" not in sound_manager
assert "public float getSoundVolume();" in sound_manager
emitter = bytecode("zombie.audio.BaseSoundEmitter")
assert "public abstract void setVolume(long, float);" in emitter

# 0.4.42 wolf melee reach: CombatManager melee range = getMaxRange() x getRangeMod(chr).
hand_weapon = bytecode("zombie.inventory.types.HandWeapon")
assert "public float getRangeMod(zombie.characters.IsoGameCharacter);" in hand_weapon
combat = bytecode("zombie.CombatManager")
valid = method(combat, "public void calcValidTargets(")
assert "HandWeapon.getMaxRange:()F" in valid and "HandWeapon.getRangeMod:(Lzombie/characters/IsoGameCharacter;)F" in valid

# 0.4.43 Lupus drunk driving: B42 intoxication stat, DRUNK moodle, car controller.
stat = bytecode("zombie.characters.CharacterStat")
assert "public static final zombie.characters.CharacterStat INTOXICATION;" in stat
stats_cls = bytecode("zombie.characters.Stats")
assert "public float get(zombie.characters.CharacterStat);" in stats_cls
assert "public boolean set(zombie.characters.CharacterStat, float);" in stats_cls
assert "setDrunkenness" not in stats_cls  # the 0.2.2 API is gone
car = bytecode("zombie.core.physics.CarController")
assert "private boolean delayCommandWhileDrunk(boolean);" in car
assert car.count("MoodleType.DRUNK") >= 3

# 0.4.44 corpse thrown into a container: the deposit path and what it flips.
igc = bytecode("zombie.characters.IsoGameCharacter")
assert "public void throwGrappledIntoInventory(zombie.inventory.ItemContainer);" in igc
assert "public boolean isGrappleThrowIntoContainer();" in igc
assert "setDoGrappleLetGo" in igc
assert "GrappledThrownIntoContainerState.setParams" in igc

# 0.4.45 "/garou" in the Lua debug console: ProcessCommand reads the entry's
# internalText field and compiles it with LuaCompiler.loadstring. The rich
# text panel that renders tooltips has the <SPACE> command the Lua relies on
# (ISRichTextPanel is Lua, checked by tests/rich_text_test.lua instead).
console = bytecode("zombie.ui.UIDebugConsole")
assert "public void ProcessCommand();" in console
assert "public zombie.ui.UITextBox2 commandLine;" in console
assert "zombie/ui/UITextBox2.internalText" in console
assert "LuaCompiler.loadstring" in console

# 0.4.46: patch every native node calculation BEFORE the heat equation
# consumes its insulation field, not just a UI getter.
node = bytecode("zombie.characters.BodyDamage.Thermoregulator$ThermalNode")
thermo = bytecode("zombie.characters.BodyDamage.Thermoregulator")
part = bytecode("zombie.characters.BodyDamage.BodyPart")
assert "private void calculateInsulation();" in node
assert "private float insulation;" in node
assert "private final float insulationLayerMultiplierUi;" in node
assert "private final zombie.characters.BodyDamage.BodyPart bodyPart;" in node
assert "public zombie.characters.IsoGameCharacter getParentChar();" in part
heat = thermo.split("private void updateNodesHeatDelta();")[1].split("private void updateHeatDeltas();")[0]
assert heat.index("ThermalNode.calculateInsulation") < heat.index("ThermalNode.insulation")
assert "insulationLayerMultiplierUi" in node.split("public float getInsulationUI();")[1]
