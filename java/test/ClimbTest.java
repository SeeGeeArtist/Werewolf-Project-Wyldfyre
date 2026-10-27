import java.lang.instrument.Instrumentation;
import net.bytebuddy.agent.ByteBuddyAgent;
import wtagarou.visuals.*;

/** 0.4.80: real ZombieBuddy advice on a fixture shaped like
 * AnimationPlayer.UpdateSkinTransforms with the B42.20.2 model-transform
 * layout (translation in m03/m13/m23, m13 = model up). */
public final class ClimbTest {
    static int checks;
    static void check(boolean ok, String why) { checks++; if (!ok) throw new AssertionError("FAIL: " + why); }
    static boolean near(float a, float b) { return Math.abs(a - b) < 1e-4f; }
    static boolean near(float a, float b, float eps) { return Math.abs(a - b) < eps; }

    /** Minimal lwjgl-style matrix: only the fields the runtime touches. */
    public static class Matrix4f { public float m03, m13, m23; }
    public static class ClimbOverFenceState {}
    public static class ClimbOverWallState {}
    public static class ClimbThroughWindowState {}
    public static class PlayerMovementState {}
    public static class PlayerOnBedState {}
    public static class PlayerSitOnFurnitureState {}
    public static class PlayerSitOnGroundState {}
    public static class Character {
        public Object state = new PlayerMovementState();
        public Object getCurrentState() { return state; }
    }
    public static class Player {
        public Player parentPlayer;
        public Character character;
        public Matrix4f[] bones;
        public int pelvis = 1;
        public int footL = -1, footR = -1;      // 0.4.82: optional foot bones
        public int handL = -1, handR = -1;      // 0.4.83: optional hand bones
        public int skinUpdates;
        Player(Character c, int boneCount, float pelvisY) {
            character = c;
            bones = new Matrix4f[boneCount];
            for (int i = 0; i < boneCount; i++) { bones[i] = new Matrix4f(); bones[i].m13 = 0.1f * i; }
            if (pelvis < boneCount) bones[pelvis].m13 = pelvisY;
        }
        public Object getIsoGameCharacter() { return character; }
        public int getModelTransformsCount() { return bones.length; }
        public Matrix4f getModelTransformAt(int i) { return bones[i]; }
        public int getSkinningBoneIndex(String name, int def) {
            if (name.equals("Bip01_Pelvis") && pelvis >= 0) return pelvis;
            if (name.equals("Bip01_L_Foot") && footL >= 0) return footL;
            if (name.equals("Bip01_R_Foot") && footR >= 0) return footR;
            if (name.equals("Bip01_L_Hand") && handL >= 0) return handL;
            if (name.equals("Bip01_R_Hand") && handR >= 0) return handR;
            return def;
        }
        public void UpdateSkinTransforms() { skinUpdates++; }
        float pelvisY() { return bones[pelvis].m13; }
    }

    public static void main(String[] args) throws Exception {
        Instrumentation inst = ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Player.class, ClimbPatch.class, "UpdateSkinTransforms");

        // Pure decisions and math.
        check(ClimbRuntime.climbing("ClimbOverFenceState") && ClimbRuntime.climbing("ClimbOverWallState")
                && ClimbRuntime.climbing("ClimbThroughWindowState"), "fence, wall and window climbs compress");
        check(!ClimbRuntime.climbing("PlayerMovementState") && !ClimbRuntime.climbing("PlayerGetUpState")
                && !ClimbRuntime.climbing(null), "locomotion, get-ups and no state do not");
        check(ClimbRuntime.offset(1.0f, 1.65f) < 0 && near(ClimbRuntime.offset(1.0f, 1.65f), -(1f - 1f / 1.65f)), "offset = -lift(1-1/s)");
        check(near(1.65f * (1.0f + 1.0f + ClimbRuntime.offset(1.0f, 1.65f)), 1.65f * 1.0f + 1.0f),
                "after FinalScale the drawn lift equals the vanilla lift (standing height stays scaled)");
        check(ClimbRuntime.offset(0f, 1.65f) == 0f && ClimbRuntime.offset(-0.3f, 1.65f) == 0f
                && ClimbRuntime.offset(1f, 1f) == 0f && ClimbRuntime.offset(1f, 0f) == 0f, "no lift, no scale, bad scale: no offset");
        // 0.4.83 hand rule, pure math.
        float k = 1f - 1f / 1.65f;
        check(near(ClimbRuntime.handOffset(1.0f, 1.0f, 1.65f), -k), "hands at 1.0 with feet clear: dy = -hand(1-1/s)");
        check(near(1.65f * (1.0f + ClimbRuntime.handOffset(1.0f, 1.0f, 1.65f)), 1.0f), "after FinalScale the hands draw at the vanilla fence top");
        check(ClimbRuntime.handOffset(0.9f, 0.0f, 1.65f) == 0f, "feet on the ground: no offset even though the hands want to come down");
        check(near(ClimbRuntime.handOffset(1.0f, 0.2f, 1.65f), -0.2f), "feet barely up: the clamp holds the feet at the ground, not below");
        check(near(ClimbRuntime.handOffset(1.0f, 0.2f, 1.65f), -0.2f) && ClimbRuntime.handOffset(1.0f, 0.2f, 1.65f) > -k, "clamp wins while it is the smaller shift");
        check(ClimbRuntime.handOffset(1.0f, 1.0f, 1f) == 0f && ClimbRuntime.handOffset(0f, 1.0f, 1.65f) == 0f
                && ClimbRuntime.handOffset(-1f, 1.0f, 1.65f) == 0f && ClimbRuntime.handOffset(1f, -5f, 1.65f) == 0f, "scale 1, hands at or below the ground, feet below ground: no offset, never positive");

        // Human-scale character climbing: untouched.
        Character human = new Character(); human.state = new ClimbOverFenceState();
        Player hp = new Player(human, 4, 1.0f);
        hp.UpdateSkinTransforms();
        check(hp.skinUpdates == 1 && near(hp.pelvisY(), 1.0f), "scale 1: bones untouched");

        // Crinos walking: untouched. Crinos climbing: the first frame sets the rest height.
        Character crinos = new Character();
        check(WTAGarouJava.setScale(crinos, 1.65), "fixture scale");
        Player cp = new Player(crinos, 4, 1.0f);
        cp.UpdateSkinTransforms();
        check(near(cp.pelvisY(), 1.0f) && near(cp.bones[3].m13, 0.3f), "walking at 1.65: untouched");
        crinos.state = new ClimbOverFenceState();
        cp.UpdateSkinTransforms();
        check(near(cp.pelvisY(), 1.0f), "first climb frame: standing, rest captured, no offset");
        // The animation lifts the whole skeleton by the fence height (1.0).
        for (Matrix4f m : cp.bones) m.m13 += 1.0f;
        cp.UpdateSkinTransforms();
        float expected = ClimbRuntime.offset(1.0f, 1.65f);
        check(near(cp.pelvisY(), 2.0f + expected), "pelvis lowered by lift(1-1/s): " + cp.pelvisY());
        check(near(cp.bones[0].m13, 1.0f + expected) && near(cp.bones[3].m13, 1.3f + expected), "every bone moves by the same offset");
        check(near(1.65f * cp.pelvisY(), 1.65f * 1.0f + 1.0f), "drawn pelvis = scaled standing height + vanilla fence height");
        // Dipping below the rest height never pushes the model into the ground.
        for (Matrix4f m : cp.bones) m.m13 = 0.1f;
        cp.bones[cp.pelvis].m13 = 0.8f;
        cp.UpdateSkinTransforms();
        check(near(cp.pelvisY(), 0.8f), "pelvis below rest: no offset");
        // A sub-model player (clothing) without the pelvis follows the body's offset.
        Player body = new Player(crinos, 3, 1.0f);
        body.UpdateSkinTransforms();                       // rest already captured for this character
        for (Matrix4f m : body.bones) m.m13 += 0.5f;
        body.UpdateSkinTransforms();
        Player cloth = new Player(null, 2, 0f); cloth.parentPlayer = body; cloth.pelvis = -1;
        cloth.bones[0].m13 = 0.4f; cloth.bones[1].m13 = 0.7f;
        cloth.UpdateSkinTransforms();
        float dy = ClimbRuntime.offset(0.5f, 1.65f);
        check(near(cloth.bones[0].m13, 0.4f + dy) && near(cloth.bones[1].m13, 0.7f + dy), "sub-model follows the body's frame offset");
        // Leaving the climb clears the entry: the next climb re-captures rest.
        crinos.state = new PlayerMovementState();
        body.UpdateSkinTransforms();
        for (Matrix4f m : body.bones) m.m13 = 1.2f;
        crinos.state = new ClimbThroughWindowState();
        body.UpdateSkinTransforms();
        check(near(body.bones[cp.pelvis].m13, 1.2f), "new climb: rest re-captured at the current height, no offset");
        // (The wolf-rig skip is a plain WolfRuntime.active guard ahead of the
        // state check; the wolf fixture needs the whole asset harness, so it is
        // not exercised here.)
        check(!ClimbRuntime.disabled && ClimbRuntime.applied.get() >= 3, "hook alive: " + ClimbRuntime.status());

        // 0.4.95: seats. Pelvis reference; split the difference when the feet would sink.
        check(ClimbRuntime.seated("PlayerOnBedState") && ClimbRuntime.seated("PlayerSitOnFurnitureState"), "bed and furniture states seat the pelvis");
        check(!ClimbRuntime.seated("PlayerSitOnGroundState") && !ClimbRuntime.seated("PlayerMovementState") && !ClimbRuntime.seated(null), "ground sitting, locomotion, no state: left alone");
        float g = 1f - 1f / 1.24f;
        float want = -0.45f * g;
        // both states are sitting poses: pelvis on the seat/mattress edge, feet on the floor
        check(near(ClimbRuntime.seatOffset(0.45f, 0.0f, 1.24f), 0.5f * want), "Glabro seated (feet on the floor): half the pelvis correction, feet sink the other half");
        check(ClimbRuntime.seatOffset(0.45f, 0.0f, 1.24f) > want && ClimbRuntime.seatOffset(0.45f, 0.0f, 1.24f) < 0f, "split sits strictly between full correction and no correction");
        check(near(1.24f * -ClimbRuntime.seatOffset(0.45f, 0.0f, 1.24f), 0.054f, 0.002f), "Glabro: drawn sink about 5 cm, under the cap");
        float seatC = ClimbRuntime.seatOffset(0.45f, 0.03f, 1.65f);
        check(near(1.65f * (0.03f + seatC), -ClimbRuntime.MAX_SINK, 0.002f), "Crinos seated: the midpoint would sink 12 cm, capped at MAX_SINK drawn: " + 1.65f * (0.03f + seatC));
        check(seatC > -0.45f * (1f - 1f / 1.65f) && seatC < 0f, "Crinos still gets part of the pelvis correction");
        check(near(ClimbRuntime.seatOffset(0.5f, 0.5f, 1.24f), -0.5f * g), "feet up with the pelvis (never the case in practice): full pelvis correction");
        check(ClimbRuntime.seatOffset(0.45f, 0.0f, 1f) == 0f && ClimbRuntime.seatOffset(0f, 0f, 1.24f) == 0f && ClimbRuntime.seatOffset(-0.2f, 0f, 1.65f) == 0f, "scale 1 or pelvis at/below the ground: no offset");
        check(ClimbRuntime.seatOffset(0.45f, -0.3f, 1.65f) <= 0f, "feet already below ground: never positive");
        Character glabro = new Character(); WTAGarouJava.setScale(glabro, 1.24);
        Player bp = new Player(glabro, 6, 0.45f); bp.footL = 4; bp.footR = 5;
        for (Matrix4f m : bp.bones) m.m13 = 0.1f;
        bp.bones[bp.pelvis].m13 = 0.45f; bp.bones[4].m13 = 0.0f; bp.bones[5].m13 = 0.0f;   // sitting on the bed edge
        glabro.state = new PlayerOnBedState();
        bp.UpdateSkinTransforms();
        check(near(bp.pelvisY(), 0.45f + 0.5f * want), "resting on a bed (a sitting pose): half correction: " + bp.pelvisY());
        check(near(bp.bones[0].m13, 0.1f + 0.5f * want) && near(bp.bones[5].m13, 0.5f * want), "every bone moves by the seat offset");
        glabro.state = new PlayerSitOnFurnitureState();
        for (Matrix4f m : bp.bones) m.m13 = 0.1f;
        bp.bones[bp.pelvis].m13 = 0.45f; bp.bones[4].m13 = 0.0f; bp.bones[5].m13 = 0.0f;
        bp.UpdateSkinTransforms();
        check(near(bp.pelvisY(), 0.45f + 0.5f * want), "on a chair: same rule: " + bp.pelvisY());
        glabro.state = new PlayerSitOnGroundState();
        for (Matrix4f m : bp.bones) m.m13 = 0.2f;
        bp.UpdateSkinTransforms();
        check(near(bp.pelvisY(), 0.2f), "sitting on the ground: untouched");

        // 0.4.82: with foot bones the LOWEST FOOT is the reference, so the feet
        // (what rests on the fence top) land at vanilla height even when they
        // rise more than the pelvis.
        Character cr2 = new Character(); WTAGarouJava.setScale(cr2, 1.65);
        Player fp = new Player(cr2, 6, 1.0f); fp.footL = 4; fp.footR = 5;
        fp.bones[4].m13 = 0.05f; fp.bones[5].m13 = 0.0f;          // standing: feet at the origin
        cr2.state = new ClimbOverFenceState();
        fp.UpdateSkinTransforms();
        check(near(fp.bones[5].m13, 0.0f) && near(fp.pelvisY(), 1.0f), "feet reference: rest frame untouched");
        // Hands on the fence, pushing up: pelvis rises 0.3, feet still on the ground.
        fp.bones[fp.pelvis].m13 = 1.3f;
        fp.UpdateSkinTransforms();
        check(near(fp.bones[5].m13, 0.0f) && near(fp.pelvisY(), 1.3f), "feet still on the ground: no offset (the pelvis rule would have sunk the feet)");
        // Straddle: feet up to the fence top (1.0), pelvis up 0.6.
        fp.bones[4].m13 = 1.05f; fp.bones[5].m13 = 1.0f; fp.bones[fp.pelvis].m13 = 1.6f;
        fp.UpdateSkinTransforms();
        float fdy = ClimbRuntime.offset(1.0f, 1.65f);
        check(near(fp.bones[5].m13, 1.0f + fdy) && near(1.65f * fp.bones[5].m13, 1.0f), "straddle: the lowest foot draws exactly at the vanilla fence top");
        check(near(fp.pelvisY(), 1.6f + fdy), "the pelvis takes the same offset (torso rightly higher on the bigger body)");
        check(near(ClimbRuntime.lastLift, 1.0f), "lift is the foot lift, not the pelvis lift: " + ClimbRuntime.lastLift);
        // The other foot being lowest is fine too.
        fp.bones[4].m13 = 0.8f; fp.bones[5].m13 = 1.2f;
        fp.UpdateSkinTransforms();
        check(near(1.65f * fp.bones[4].m13, 0.8f), "the lower of the two feet is the reference");
        check(ClimbRuntime.status().contains("last lift=0.8"), "status reports the foot lift: " + ClimbRuntime.status());
        // 0.4.83: with hand bones the HANDS are the reference, measured from
        // the ground, clamped by the lowest foot. No rest frame, no bob.
        Character cr3 = new Character(); WTAGarouJava.setScale(cr3, 1.65);
        Player hp3 = new Player(cr3, 8, 1.0f); hp3.footL = 4; hp3.footR = 5; hp3.handL = 6; hp3.handR = 7;
        // Entered mid-blend: feet already slightly up, hands at the sides (0.9).
        hp3.bones[4].m13 = 0.05f; hp3.bones[5].m13 = 0.0f; hp3.bones[6].m13 = 0.9f; hp3.bones[7].m13 = 0.9f;
        cr3.state = new ClimbOverWallState();                      // 0.4.96: hands rule is for walls/windows
        hp3.UpdateSkinTransforms();
        check(near(hp3.bones[5].m13, 0.0f) && near(hp3.pelvisY(), 1.0f), "hands reference: feet on the ground, no offset");
        check(ClimbRuntime.status().contains("last lift=0.9"), "status reports the hand height: " + ClimbRuntime.status());
        // Hands on the rail (1.0), feet just leaving the ground (0.1): the clamp holds the feet on the ground.
        hp3.bones[6].m13 = 1.0f; hp3.bones[7].m13 = 1.0f; hp3.bones[4].m13 = 0.15f; hp3.bones[5].m13 = 0.1f; hp3.bones[hp3.pelvis].m13 = 1.1f;
        hp3.UpdateSkinTransforms();
        check(near(hp3.bones[5].m13, 0.0f) && near(hp3.pelvisY(), 1.0f), "feet barely up: the lowest foot is held at the ground: " + hp3.bones[5].m13);
        // Straddle: hands planted at 1.0, feet up at the rail, legs kicking.
        hp3.bones[6].m13 = 1.0f; hp3.bones[7].m13 = 1.0f; hp3.bones[4].m13 = 1.1f; hp3.bones[5].m13 = 0.9f; hp3.bones[hp3.pelvis].m13 = 1.6f;
        hp3.UpdateSkinTransforms();
        float hdy = ClimbRuntime.handOffset(1.0f, 0.9f, 1.65f);
        check(near(hdy, -k), "straddle offset is the full hand offset");
        check(near(1.65f * hp3.bones[6].m13, 1.0f) && near(1.65f * hp3.bones[7].m13, 1.0f), "straddle: both hands draw exactly at the vanilla fence top");
        check(near(hp3.pelvisY(), 1.6f + hdy), "the pelvis takes the same offset");
        float straddlePelvis = hp3.pelvisY();
        // The legs kick: the feet alternate, the hands stay planted. Reset the
        // bones to the raw pose each frame (the engine recomputes them) and
        // swap which foot is lower: the offset must not change at all.
        for (int kick = 0; kick < 4; kick++) {
            boolean left = (kick & 1) == 0;
            hp3.bones[6].m13 = 1.0f; hp3.bones[7].m13 = 1.0f; hp3.bones[hp3.pelvis].m13 = 1.6f;
            hp3.bones[4].m13 = left ? 0.7f : 1.2f; hp3.bones[5].m13 = left ? 1.2f : 0.7f;
            hp3.UpdateSkinTransforms();
            check(near(hp3.pelvisY(), straddlePelvis), "kicking legs do not bob the body (kick " + kick + "): " + hp3.pelvisY());
            check(near(1.65f * hp3.bones[6].m13, 1.0f), "hands stay on the rail while the legs kick");
        }
        // One hand off the rail swinging low: the mean moves the body only half as much as the lowest hand would.
        hp3.bones[6].m13 = 1.0f; hp3.bones[7].m13 = 0.6f; hp3.bones[4].m13 = 1.0f; hp3.bones[5].m13 = 1.0f; hp3.bones[hp3.pelvis].m13 = 1.6f;
        hp3.UpdateSkinTransforms();
        check(near(hp3.pelvisY(), 1.6f + ClimbRuntime.handOffset(0.8f, 1.0f, 1.65f)), "the reference is the mean of both hands");
        // Landing: feet back on the ground, hands drop to the sides: offset returns to zero smoothly through the clamp.
        hp3.bones[6].m13 = 0.9f; hp3.bones[7].m13 = 0.9f; hp3.bones[4].m13 = 0.1f; hp3.bones[5].m13 = 0.1f; hp3.bones[hp3.pelvis].m13 = 1.05f;
        hp3.UpdateSkinTransforms();
        check(near(hp3.bones[4].m13, 0.0f) && near(hp3.pelvisY(), 0.95f), "landing: the clamp carries the offset back toward zero: " + hp3.pelvisY());
        hp3.bones[6].m13 = 0.9f; hp3.bones[7].m13 = 0.9f; hp3.bones[4].m13 = 0.0f; hp3.bones[5].m13 = 0.0f; hp3.bones[hp3.pelvis].m13 = 1.0f;
        hp3.UpdateSkinTransforms();
        check(near(hp3.pelvisY(), 1.0f), "landed: no offset");
        // 0.4.96: the low-fence hop (ClimbOverFenceState) uses the LOWEST FOOT
        // even with hand bones: the feet pass over the rail, the hands rule
        // dragged them scale x further below the hands and through it.
        check(ClimbRuntime.hop("ClimbOverFenceState") && !ClimbRuntime.hop("ClimbOverWallState") && !ClimbRuntime.hop("ClimbThroughWindowState"), "only the hoppable-fence state is a hop");
        check(near(ClimbRuntime.hopOffset(1.0f, 1.65f), ClimbRuntime.offset(1.0f, 1.65f)), "hop offset = foot lift compressed by 1/scale");
        check(ClimbRuntime.hopOffset(0f, 1.65f) == 0f && ClimbRuntime.hopOffset(-0.1f, 1.65f) == 0f && ClimbRuntime.hopOffset(1f, 1f) == 0f, "hop: feet on/below the ground or scale 1: nothing");
        Character cr4 = new Character(); WTAGarouJava.setScale(cr4, 1.65);
        Player hop = new Player(cr4, 8, 1.0f); hop.footL = 4; hop.footR = 5; hop.handL = 6; hop.handR = 7;
        cr4.state = new ClimbOverFenceState();
        hop.bones[6].m13 = 0.9f; hop.bones[7].m13 = 0.9f; hop.bones[4].m13 = 0.05f; hop.bones[5].m13 = 0.0f;
        hop.UpdateSkinTransforms();
        check(near(hop.pelvisY(), 1.0f), "hop approach: feet on the ground, no offset");
        // Mid-vault: hands swung up (1.3), feet passing over the rail at 1.0 / 1.1, pelvis 1.5.
        hop.bones[6].m13 = 1.3f; hop.bones[7].m13 = 1.3f; hop.bones[4].m13 = 1.1f; hop.bones[5].m13 = 1.0f; hop.bones[hop.pelvis].m13 = 1.5f;
        hop.UpdateSkinTransforms();
        check(near(1.65f * hop.bones[5].m13, 1.0f), "hop: the lowest foot draws exactly at the vanilla rail height (clears the fence)");
        check(1.65f * hop.bones[6].m13 > 1.0f, "hop: the hands float above the rail instead of the feet going through it");
        check(ClimbRuntime.status().contains("last lift=1.0"), "status reports the foot height: " + ClimbRuntime.status());
        // Same pose under the hands rule (wall) sinks the feet below the rail: the bug the hop rule fixes.
        float wallFoot = 1.65f * (1.0f + ClimbRuntime.handOffset(1.3f, 1.0f, 1.65f));
        check(wallFoot < 1.0f - 0.15f, "for comparison the hands rule would draw that foot " + (1.0f - wallFoot) + " m below the rail");
        // Landing.
        hop.bones[6].m13 = 0.9f; hop.bones[7].m13 = 0.9f; hop.bones[4].m13 = 0.0f; hop.bones[5].m13 = 0.0f; hop.bones[hop.pelvis].m13 = 1.0f;
        hop.UpdateSkinTransforms();
        check(near(hop.pelvisY(), 1.0f), "hop landed: no offset");
        // Glabro at 1.24 gets the same treatment at its own scale.
        Character gl = new Character(); WTAGarouJava.setScale(gl, 1.24);
        Player gp = new Player(gl, 8, 1.0f); gp.footL = 4; gp.footR = 5; gp.handL = 6; gp.handR = 7;
        gp.bones[6].m13 = 1.0f; gp.bones[7].m13 = 1.0f; gp.bones[4].m13 = 1.0f; gp.bones[5].m13 = 1.0f;
        gl.state = new ClimbThroughWindowState();
        gp.UpdateSkinTransforms();
        check(near(1.24f * gp.bones[6].m13, 1.0f), "Glabro through a window: hands on the sill at vanilla height");
        // Pelvis layout check still guards: odd pelvis with sane feet fails closed (tested below with the odd fixture).
        // An implausible pelvis height (wrong matrix layout) fails closed once.
        Character odd = new Character(); odd.state = new ClimbOverWallState();
        WTAGarouJava.setScale(odd, 1.24);
        Player op = new Player(odd, 3, 40f);
        op.UpdateSkinTransforms();
        check(ClimbRuntime.disabled && near(op.pelvisY(), 40f), "unexpected layout disables the hook, bones untouched");
        System.out.println("PASS ClimbTest (" + checks + " checks)");
    }
}
