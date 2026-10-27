package wtagarou.visuals;

import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.17: after the engine has placed a sub-model on its parent bone, turn
 * the jaw-carried item so a tool lies sideways across the muzzle. The render
 * data keeps xfrm TRANSPOSED (transformToParent ends with transpose()), so
 * the extra local-space rotation/offset is post-multiplied between two
 * transposes. Values come from WTAGarou.MouthCarry via WTAGarouJava. */
@Patch(className = "zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData",
        methodName = "transformToParent", warmUp = true)
public final class MouthCarryPatch {
    public static volatile boolean observed, applied, saddlebagApplied, slotApplied, translateLocalMissing;
    public static volatile String lastError;
    public static final Class<?>[] FLOAT3 = { float.class, float.class, float.class };
    public static final Class<?>[] FLOAT1 = { float.class };
    public static final double DEG = Math.PI / 180.0;

    @Patch.OnEnter
    public static void enter(@Patch.This Object self, @Patch.Argument(0) Object parent) {
        // 0.4.25: model rebuilds bake bone/scale into xfrm BEFORE DrawChar.
        // Retarget and compensate before that bake, including the first
        // frame after clothing/equip rebuilds. Draw-time preparation was late.
        if (parent != null) WolfRuntime.hideSubmodel(null, self);
    }

    @Patch.OnExit
    public static void exit(@Patch.This Object self, @Patch.Argument(0) Object parent) {
        observed = true;
        if (self == null || parent == null) return;
        try {
            Object instance = Reflect.get(self, "modelInstance");
            float offX, offY, offZ, rotX, rotY, rotZ, scale = 1f;
            String pivotKey = null;
            float units = 1f;
            if (WolfRuntime.mouthCarry && WolfRuntime.isMouthCarried(instance)) {
                pivotKey = "mouth";
                offX = WolfRuntime.mouthOffX; offY = WolfRuntime.mouthOffY; offZ = WolfRuntime.mouthOffZ;
                rotX = WolfRuntime.mouthRotX; rotY = WolfRuntime.mouthRotY; rotZ = WolfRuntime.mouthRotZ;
            } else if (WolfRuntime.isSaddlebag(instance)) {
                pivotKey = "saddlebag";
                units = WolfRuntime.bagImportUnits(instance);
                // 0.4.22: the saddlebag gets the same post-transform, from WTAGarou.Saddlebag.
                offX = WolfRuntime.saddleOffX; offY = WolfRuntime.saddleOffY; offZ = WolfRuntime.saddleOffZ;
                rotX = WolfRuntime.saddleRotX; rotY = WolfRuntime.saddleRotY; rotZ = WolfRuntime.saddleRotZ;
                scale = WolfRuntime.saddleScale;
                if (offX == 0f && offY == 0f && offZ == 0f && rotX == 0f && rotY == 0f && rotZ == 0f && scale == 1f
                        && !WolfRuntime.ATTACHMENT_PIVOTS.containsKey(pivotKey)) return;
            } else if (WolfRuntime.isHarness(instance)) {
                // Skin weights supply all local deformation. ScaleRuntime
                // applies the body's FinalScale; no static matrix scale.
                return;
            } else if (WolfRuntime.slotRuleFor(instance) != null) {
                // 0.4.23: hotbar / secondary-hand item on the wolf. Offset is
                // PRE-multiplied (translateLocal: character space, Y up, so
                // "raise it" is +Y regardless of the item's own axes);
                // rotation stays in the item's space like the others.
                WolfRuntime.SlotRule rule = WolfRuntime.slotRuleFor(instance);
                if (rule.identity()) return;
                Object xfrm = Reflect.get(self, "xfrm");
                if (xfrm == null) return;
                Reflect.call(xfrm, "transpose");
                if (rule.offX != 0f || rule.offY != 0f || rule.offZ != 0f) {
                    if (!translateLocalMissing) {
                        try { Reflect.call(xfrm, "translateLocal", FLOAT3, rule.offX, rule.offY, rule.offZ); }
                        catch (ReflectiveOperationException | RuntimeException error) {
                            translateLocalMissing = true;
                            System.out.println("[WTAGarou Java] slot offset: translateLocal unavailable (" + error + "); using item-space translate");
                        }
                    }
                    if (translateLocalMissing) Reflect.call(xfrm, "translate", FLOAT3, rule.offX, rule.offY, rule.offZ);
                }
                if (rule.rotX != 0f || rule.rotY != 0f || rule.rotZ != 0f) {
                    Reflect.call(xfrm, "rotateXYZ", FLOAT3,
                            (float) (rule.rotX * DEG), (float) (rule.rotY * DEG), (float) (rule.rotZ * DEG));
                }
                // 0.4.24: shift the mesh so its grip point sits on the mount.
                if (rule.hasPivot()) Reflect.call(xfrm, "translate", FLOAT3, -rule.pivotX, -rule.pivotY, -rule.pivotZ);
                Reflect.call(xfrm, "transpose");
                applied = true; slotApplied = true;
                return;
            } else {
                return;
            }
            Object xfrm = Reflect.get(self, "xfrm");
            if (xfrm == null) return;
            Reflect.call(xfrm, "transpose");
            if (offX != 0f || offY != 0f || offZ != 0f) {
                Reflect.call(xfrm, "translate", FLOAT3, offX/units, offY/units, offZ/units);
            }
            if (rotX != 0f || rotY != 0f || rotZ != 0f) {
                Reflect.call(xfrm, "rotateXYZ", FLOAT3,
                        (float) (rotX * DEG), (float) (rotY * DEG), (float) (rotZ * DEG));
            }
            if (scale != 1f && scale > 0f) Reflect.call(xfrm, "scale", FLOAT1, scale);
            float[] pivot=WolfRuntime.ATTACHMENT_PIVOTS.get(pivotKey);
            if (pivot != null) Reflect.call(xfrm,"translate",FLOAT3,-pivot[0]/units,-pivot[1]/units,-pivot[2]/units);
            Reflect.call(xfrm, "transpose");
            applied = true;
            if (WolfRuntime.isSaddlebag(instance)) saddlebagApplied = true;
        } catch (ReflectiveOperationException | RuntimeException error) {
            if (lastError == null) {
                lastError = String.valueOf(error);
                System.out.println("[WTAGarou Java] mouth carry transform: " + lastError);
            }
        } finally {
            WolfRuntime.bakeSubmodelScale(self, parent);
            WolfRuntime.publishSubmodelTransform(self);
        }
    }

    public static String status() {
        return "mouth transform hook=" + observed + "; applied=" + applied + "; saddlebag=" + saddlebagApplied + "; slot=" + slotApplied
                + (lastError != null ? "; error=" + lastError : "");
    }
}
