package wtagarou.visuals;

import java.util.ArrayDeque;
import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

/** 0.4.69: crowd charge. A sprinting Crinos that runs into zombies used to
 *  stumble on the first one (and flinch it). IsoMovingObject.separate() is
 *  the whole mechanic: when a running player overlaps a zombie it calls, in
 *  this order, setLastBump, setBumpedChr(zombie), setBumpType(player),
 *  zombie.setBumpType(flinch), setHitFromBehind, and (sprinting) rolls
 *  setBumpFall(true) first and reports "wasBumped" last, which enters the
 *  BumpedState stumble that kills the sprint.
 *
 *  While a registered form sprints, the first LIMIT collisions inside a
 *  WINDOW are charges: the zombie is knocked down (IsoZombie.knockDown, the
 *  same public call a shove ends in), the player's bump type and fall are
 *  dropped, the zombie's flinch bump is dropped and the "wasBumped" event
 *  is swallowed, so the sprint continues. Collision LIMIT+1 inside the
 *  window is a vanilla bump (the crowd stopped the charge). The scope is a
 *  ThreadLocal opened in setBumpedChr and closed at the event (or by the
 *  next setBumpedChr / 200 ms), so nothing outside that call sequence is
 *  touched. */
public final class CrowdChargeRuntime {
    public static final class Rule { final int limit; final long windowMs; Rule(int l,long w){limit=l;windowMs=w;} }
    private static final Map<Object,Rule> RULES=Collections.synchronizedMap(new WeakHashMap<>());
    private static final Map<Object,ArrayDeque<Long>> HITS=Collections.synchronizedMap(new WeakHashMap<>());
    private static final ThreadLocal<Object[]> SCOPE=new ThreadLocal<>(); // {player, zombie, Long openedAt}
    public static volatile long knockdowns, crowdStops, bumpsSwallowed, eventsSwallowed;
    private static boolean logged;
    /** Test seam: System.currentTimeMillis by default. */
    public static java.util.function.LongSupplier clock=System::currentTimeMillis;

    private CrowdChargeRuntime() {}

    public static boolean set(Object character,int limit,double windowSeconds) {
        if (character==null) return false;
        if (limit<=0) { RULES.remove(character); HITS.remove(character); return true; }
        RULES.put(character,new Rule(limit,(long)Math.max(100,windowSeconds*1000)));
        return true;
    }
    public static void clear(Object character) { if (character!=null) { RULES.remove(character); HITS.remove(character); } }
    public static void clearAll() { RULES.clear(); HITS.clear(); }
    public static boolean active(Object character) { return character!=null && RULES.containsKey(character); }

    /** IsoGameCharacter.setBumpedChr(IsoGameCharacter) enter: the player is
     *  `this`, the thing it ran into is the argument. */
    public static void onBumped(Object player,Object other) {
        SCOPE.remove();
        if (player==null || other==null) return;
        Rule rule=RULES.get(player);
        if (rule==null) return;
        try {
            if (!Boolean.TRUE.equals(Reflect.call(player,"isSprinting"))) return;
            if (!isZombie(other) || Boolean.TRUE.equals(Reflect.call(other,"isOnFloor"))) return;
            long now=clock.getAsLong();
            ArrayDeque<Long> hits=HITS.computeIfAbsent(player,k->new ArrayDeque<>());
            while (!hits.isEmpty() && now-hits.peekFirst()>rule.windowMs) hits.pollFirst();
            if (hits.size()>=rule.limit) {
                crowdStops++;
                hits.clear(); // the crowd stopped the charge; the next sprint starts clean
                return;       // vanilla bump
            }
            hits.addLast(now);
            boolean fromBehind=isBehind(player,other);
            Reflect.call(other,"knockDown",new Class<?>[]{boolean.class},fromBehind);
            knockdowns++;
            SCOPE.set(new Object[]{player,other,now});
            // separate() rolled setBumpFall(true) before this call (sprinting always
            // trips); undo it so the charger never goes down on a charge.
            Reflect.call(player,"setBumpFall",boolean.class,false);
            if (!logged) {
                logged=true;
                System.out.println("[WTAGarou Java][CrowdCharge] sprinting into a zombie: knocked down, no stumble (limit "+rule.limit+" per "+rule.windowMs+" ms)");
            }
        } catch (ReflectiveOperationException | RuntimeException e) {
            SCOPE.remove();
            System.out.println("[WTAGarou Java][CrowdCharge] unavailable: "+e);
            RULES.remove(player);
        }
    }

    private static boolean inScope(Object who) {
        Object[] s=SCOPE.get();
        if (s==null) return false;
        if (clock.getAsLong()-(Long)s[2]>200) { SCOPE.remove(); return false; }
        return s[0]==who || s[1]==who;
    }
    /** setBumpType value to store for `who` (player or zombie in the scope). */
    public static String filterBumpType(Object who,String type) {
        if (type==null || type.isEmpty() || !inScope(who)) return type;
        bumpsSwallowed++;
        return "";
    }
    /** setBumpFall value for the charging player (late trips inside the scope). */
    public static boolean filterBumpFall(Object who,boolean fall) {
        return fall && !inScope(who);
    }
    /** ActionContextEvents.add(event,state) enter: true = swallow. Closes the scope. */
    public static boolean swallowEvent(String event) {
        if (!"wasBumped".equals(event)) return false;
        Object[] s=SCOPE.get();
        if (s==null) return false;
        SCOPE.remove();
        if (clock.getAsLong()-(Long)s[2]>200) return false;
        eventsSwallowed++;
        return true;
    }
    public static boolean scopeOpen() { return SCOPE.get()!=null; }

    /** IsoGameCharacter.isBehind(IsoGameCharacter): looked up by name and an
     *  assignable single parameter so the test fixture's shape works too. */
    private static boolean isBehind(Object player,Object other) throws ReflectiveOperationException {
        for (java.lang.reflect.Method m : player.getClass().getMethods()) {
            if (!m.getName().equals("isBehind") || m.getParameterCount()!=1) continue;
            if (!m.getParameterTypes()[0].isInstance(other)) continue;
            return Boolean.TRUE.equals(m.invoke(player,other));
        }
        return false;
    }
    private static boolean isZombie(Object other) {
        for (Class<?> c=other.getClass(); c!=null; c=c.getSuperclass())
            if (c.getSimpleName().equals("IsoZombie") || c.getSimpleName().equals("Zombie")) return true;
        return false;
    }
    public static String status() {
        return "crowd charge registered="+RULES.size()+"; knockdowns="+knockdowns+"; crowd stops="+crowdStops
                +"; bumps swallowed="+bumpsSwallowed+"; events swallowed="+eventsSwallowed;
    }
}
