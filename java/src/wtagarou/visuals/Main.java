package wtagarou.visuals;

import java.io.File;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.TreeSet;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;
import me.zed_0xff.zombie_buddy.Patch;

/** Entry point ZombieBuddy calls BEFORE it scans this jar for @Patch classes.
 *
 * 0.4.98: every class we patch is loaded here first (not initialised), so
 * ZombieBuddy retransforms all of them in its one install pass. Without
 * this, a class the JVM first loads WHILE another class is being
 * retransformed (the verifier pulls in IsoGameCharacter's field and method
 * types: ModelManager, HumanVisual, AnimationPlayer, ...) is skipped by
 * ByteBuddy's circularity lock and never patched. That is what happened
 * when the Workshop copy loaded on the first mod pass at startup on a
 * Steam Deck: 21 of 64 advices missing, so the wolf body was invisible
 * and Crinos kept the human body. The second mod pass on the PC (mods
 * loaded after the main menu) had those classes loaded already, which is
 * why the same jar worked there. */
public final class Main {
    public static final String VERSION = "0.4.98";

    /** Fallback list, kept equal to the @Patch classNames by PatchTargetsTest. */
    static final String[] PATCH_TARGETS = {
        "zombie.CombatManager",
        "zombie.ai.states.SwipeStatePlayer",
        "zombie.characters.BodyDamage.BodyDamage",
        "zombie.characters.BodyDamage.BodyPart",
        "zombie.characters.BodyDamage.Thermoregulator$ThermalNode",
        "zombie.characters.CharacterTimedActions.BaseAction",
        "zombie.characters.IsoGameCharacter",
        "zombie.characters.IsoPlayer",
        "zombie.characters.IsoZombie",
        "zombie.characters.action.ActionContextEvents",
        "zombie.core.skinnedmodel.BaseGrappleable",
        "zombie.core.skinnedmodel.DeadBodyAtlas$BodyParams",
        "zombie.core.skinnedmodel.ModelManager",
        "zombie.core.skinnedmodel.advancedanimation.AnimatedModel",
        "zombie.core.skinnedmodel.advancedanimation.AnimatedModel$AnimatedModelInstanceRenderData",
        "zombie.core.skinnedmodel.advancedanimation.LiveAnimNode",
        "zombie.core.skinnedmodel.animation.AnimationPlayer",
        "zombie.core.skinnedmodel.model.Model",
        "zombie.core.skinnedmodel.model.ModelInstance",
        "zombie.core.skinnedmodel.model.ModelInstanceTextureCreator",
        "zombie.core.skinnedmodel.population.PopTemplateManager",
        "zombie.core.skinnedmodel.visual.HumanVisual",
        "zombie.inventory.InventoryItem",
        "zombie.inventory.ItemTags",
        "zombie.inventory.types.HandWeapon",
        "zombie.iso.IsoGridSquare",
        "zombie.iso.IsoMovingObject",
        "zombie.seating.SeatingManager",
        "zombie.ui.UIDebugConsole",
        "zombie.vehicles.BaseVehicle",
    };

    /** Target class names read from the @Patch annotations in our own jar;
     * falls back to PATCH_TARGETS when the jar cannot be scanned. */
    static TreeSet<String> patchTargets() {
        TreeSet<String> targets = new TreeSet<>();
        try {
            File jar = new File(Main.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            if (jar.isFile()) {
                try (JarFile file = new JarFile(jar)) {
                    Enumeration<JarEntry> entries = file.entries();
                    while (entries.hasMoreElements()) {
                        String name = entries.nextElement().getName();
                        if (!name.startsWith("wtagarou/visuals/") || !name.endsWith(".class")) continue;
                        String cls = name.substring(0, name.length() - 6).replace('/', '.');
                        Patch patch = Class.forName(cls, false, Main.class.getClassLoader()).getAnnotation(Patch.class);
                        if (patch != null) targets.add(patch.className());
                    }
                }
            }
        } catch (Throwable error) {
            System.out.println("[WTAGarou Java] patch target scan failed (" + error + "); using the built-in list");
            targets.clear();
        }
        if (targets.isEmpty()) for (String name : PATCH_TARGETS) targets.add(name);
        return targets;
    }

    /** Loads (does not initialise) every patch target. Returns the names it could not load. */
    static List<String> preloadPatchTargets(Iterable<String> targets) {
        List<String> missing = new ArrayList<>();
        ClassLoader loader = Main.class.getClassLoader();
        if (loader == null) loader = ClassLoader.getSystemClassLoader();
        for (String name : targets) {
            try {
                Class.forName(name, false, loader);
            } catch (Throwable error) {
                missing.add(name);
            }
        }
        return missing;
    }

    public static void main(String[] args) {
        TreeSet<String> targets = patchTargets();
        List<String> missing = preloadPatchTargets(targets);
        System.out.println("[WTAGarou Java] " + VERSION + " loaded; patch targets preloaded="
                + (targets.size() - missing.size()) + "/" + targets.size()
                + (missing.isEmpty() ? "" : "; not found=" + missing));
    }
}
