package wtagarou.visuals;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** 0.4.69: tell the spacebar shove and the ctrl+click unarmed attack apart.
 *
 * Vanilla makes them the same attack: CombatManager.calculateAttackVars forces
 * doShove=true whenever the weapon is BareHands, so isDoShove() is true for
 * both and the shove AnimState plays for both. The only difference survives
 * at input time: IsoPlayer.meleePressed (the Melee/shove button) is true for
 * the spacebar and false for the attack button. IsoPlayer.update assigns it
 * before either path calls pressedAttack, so an OnEnter hook there sees the
 * value that belongs to this press.
 *
 * WTAGarouCrinosSwing (anim variable, read by the WTAGarouCrinosClaw node and
 * by the Lua hit-sound hook) = Crinos unarmed AND attack button, decided once
 * per attack start. The spacebar shove keeps the vanilla shove node and its
 * vanilla audio. */
public final class CrinosSwingRuntime {
    public static final String UNARMED_VARIABLE="WTAGarouCrinosUnarmed";
    public static final String SWING_VARIABLE="WTAGarouCrinosSwing";
    public static final AtomicLong swings=new AtomicLong(), shoves=new AtomicLong();
    private static final AtomicBoolean LOGGED=new AtomicBoolean(), WARNED=new AtomicBoolean();

    private CrinosSwingRuntime() {}

    /** IsoPlayer.pressedAttack enter. Returns the value written (or the
     *  untouched state when no decision was made). */
    public static boolean onPressedAttack(Object player) {
        if (player==null) return false;
        try {
            // A press that lands while an attack is already running must not
            // re-decide the node mid-animation (space tapped during a swing).
            if (Boolean.TRUE.equals(Reflect.call(player,"isAttackStarted"))) return false;
            boolean unarmed=Boolean.TRUE.equals(Reflect.call(player,"getVariableBoolean",new Class<?>[]{String.class},UNARMED_VARIABLE));
            boolean melee=Boolean.TRUE.equals(Reflect.call(player,"isMeleePressed"));
            boolean swing=unarmed && !melee;
            Reflect.call(player,"setVariable",new Class<?>[]{String.class,boolean.class},SWING_VARIABLE,swing);
            if (unarmed) {
                if (swing) swings.incrementAndGet(); else shoves.incrementAndGet();
                if (LOGGED.compareAndSet(false,true))
                    System.out.println("[WTAGarou Java][CrinosSwing] unarmed Crinos attack: "+(swing?"attack button -> one-handed swing node + club hit audio":"shove button -> vanilla shove, vanilla audio"));
            }
            return swing;
        } catch (ReflectiveOperationException | RuntimeException e) {
            if (WARNED.compareAndSet(false,true)) System.out.println("[WTAGarou Java][CrinosSwing] press hook unavailable: "+e);
            return false;
        }
    }
}
