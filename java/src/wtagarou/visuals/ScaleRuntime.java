package wtagarou.visuals;

import java.lang.reflect.Field;
import java.util.concurrent.atomic.AtomicBoolean;

/** Independent implementation using the render fields evidenced in the
 * DynamicModelScale JAR. No DMS classes or game classes are bundled.
 * Reflection is cached per class and keeps the build independent of a
 * proprietary game JAR. Unknown layouts fail closed once, not every frame. */
public final class ScaleRuntime {
    public static volatile boolean observed;
    public static volatile boolean scaled;
    public static volatile boolean disabled;
    private static final AtomicBoolean WARNED = new AtomicBoolean();

    private static final ClassValue<Access> FIELDS = new ClassValue<>() {
        @Override protected Access computeValue(Class<?> type) {
            return new Access(type);
        }
    };

    private static final class Access {
        final Field finalScale, character, modelInstance;
        Access(Class<?> type) {
            finalScale = field(type, "finalScale");
            character = field(type, "character");
            modelInstance = field(type, "modelInstance");
        }
        private static Field field(Class<?> type, String name) {
            try { return type.getField(name); }
            catch (NoSuchFieldException ignored) { return null; }
        }
    }

    public static final class SavedScale {
        final Object slot;
        final Field field;
        final float original;
        SavedScale(Object slot, Field field, float original) {
            this.slot = slot;
            this.field = field;
            this.original = original;
        }
    }

    public static Object begin(Object slot, Object renderData) {
        observed = true;
        if (disabled || slot == null || renderData == null) return null;
        try {
            Access slotFields = FIELDS.get(slot.getClass());
            Access dataFields = FIELDS.get(renderData.getClass());
            if (slotFields.finalScale == null || dataFields.modelInstance == null) {
                throw new IllegalStateException("unsupported DrawChar render layout");
            }
            Object instance = dataFields.modelInstance.get(renderData);
            if (instance == null) return null;
            Access instanceFields = FIELDS.get(instance.getClass());
            if (instanceFields.character == null) {
                throw new IllegalStateException("ModelInstance.character unavailable");
            }
            Object character = instanceFields.character.get(instance);
            // Some gear submodels omit character; their owning slot has it.
            if (character == null && slotFields.character != null) {
                character = slotFields.character.get(slot);
            }
            float factor = WTAGarouJava.scaleFor(character);
            // STATIC gear carries its complete scale in the queued xfrm.
            // The skinned harness is different: Shader.startCharacter reads
            // its palette instead of xfrm, so it must use the BODY's scale.
            boolean harness=WolfRuntime.active(character) && WolfRuntime.isHarness(instance)
                    && WolfRuntime.attachedToWolf(instance,character);
            if (WolfRuntime.active(character)
                    && (Reflect.get(instance, "model") == WolfRuntime.modelFor(character) || harness)) {
                factor *= WolfRuntime.BODY_SCALE;
                if (harness) WolfHarness.noteScale(factor);
            } else if (WolfRuntime.active(character)
                    && WolfRuntime.attachedToWolf(instance, character)) {
                factor = 1f;
            }
            SubmodelDiag.check(instance, renderData, slot, character, factor);
            if (factor == 1.0f) return null;
            float original = slotFields.finalScale.getFloat(slot);
            SavedScale saved = new SavedScale(slot, slotFields.finalScale, original);
            slotFields.finalScale.setFloat(slot, original * factor);
            if (!scaled) {
                scaled = true;
                System.out.println("[WTAGarou Java] first scaled DrawChar; factor=" + factor);
            }
            return saved;
        } catch (ReflectiveOperationException | RuntimeException error) {
            fail(error);
            return null;
        }
    }

    /** Also runs on exceptional draw exits. Restore precisely the entry
     * value rather than resetting everyone to 1 or accumulating scale. */
    public static void end(Object state) {
        if (!(state instanceof SavedScale)) return;
        SavedScale saved = (SavedScale) state;
        try { saved.field.setFloat(saved.slot, saved.original); }
        catch (ReflectiveOperationException | RuntimeException error) { fail(error); }
    }

    private static void fail(Exception error) {
        disabled = true;
        if (WARNED.compareAndSet(false, true)) {
            System.out.println("[WTAGarou Java] scale hook disabled: " + error);
        }
    }
}
