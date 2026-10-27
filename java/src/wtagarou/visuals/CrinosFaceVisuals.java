package wtagarou.visuals;

import java.util.Locale;
import zombie.core.skinnedmodel.visual.ItemVisuals;

/** Filters render-time snapshots only. Never edits worn items or saved makeup. */
public final class CrinosFaceVisuals {
    private static final ThreadLocal<Boolean> RENDER = new ThreadLocal<>();
    /** 0.4.69: the digitigrade legs are on for the character being populated. */
    private static final ThreadLocal<Boolean> LEGS = new ThreadLocal<>();
    public static volatile long footwearHidden, faceGearHidden, legwearHidden;
    private static boolean loggedFootwear, loggedFaceGear, loggedLegwear;

    public static Object enter(boolean enabled) {
        Boolean old=RENDER.get();
        RENDER.set(enabled);
        return old;
    }
    public static void leave(Object previous) {
        if(previous instanceof Object[] pair) {           // texture scope token: {render, legs}
            if(pair[1]==null) LEGS.remove(); else LEGS.set((Boolean)pair[1]);
            previous=pair[0];
        }
        if(previous==null) RENDER.remove(); else RENDER.set((Boolean)previous);
    }
    public static boolean enabled() { return Boolean.TRUE.equals(RENDER.get()); }

    /** Read-only transition evidence: distinguishes a stale render from an
     * absent saved cosmetic without trying to invent or reapply makeup. */
    public static void reportSaved(Object character,boolean crinos) {
        Object previous=enter(false);
        try {
            Object visual=Reflect.call(character,"getHumanVisual");
            Object saved=visual==null ? null : Reflect.call(visual,"getBodyVisuals");
            if(saved instanceof Iterable<?> items) {
                int makeup=0;
                for(Object item:items) if(hidden(item)) makeup++;
                System.out.println("[WTAGarou Java][CrinosMakeup] crinos="+crinos
                        +"; saved makeup entries="+makeup+"; saved visuals not modified");
            }
        } catch(ReflectiveOperationException | RuntimeException ignored) {
            // Optional diagnostic only; missing visual must never block a shift.
        } finally { leave(previous); }
    }

    public static Object enterPopulation(Object character,Object slot) {
        LEGS.set(CrinosCosmetics.legsActive(character));
        return enter(CrinosCosmetics.active(character) && CrinosCosmetics.hasHead(slot));
    }
    public static boolean legsScope() { return Boolean.TRUE.equals(LEGS.get()); }
    public static Object enterTexture(Object[] args) {
        Object body=null;
        try {
            if(args.length==3) body=args[2]; // Base/HumanVisual, ItemVisuals, ModelInstance
            else if(args.length==1 && args[0]!=null) {
                Object sprite=Reflect.get(args[0],"legsSprite");
                Object slot=sprite==null ? null : Reflect.get(sprite,"modelSlot");
                body=slot==null ? null : Reflect.get(slot,"model");
            }
            // Two-argument animal init deliberately has no Crinos scope.
        } catch(ReflectiveOperationException | RuntimeException ignored) {
            // Unknown engine shape: don't hide anything or mutate saved data.
        }
        // 0.4.71: the texture compositor is where texture-only legwear is
        // painted, so the legs scope has to be known here as well (restored
        // by leave() so a nested texture init never clears the population's).
        Boolean oldLegs=LEGS.get();
        LEGS.set(CrinosCosmetics.legsOnBody(body));
        return new Object[]{enter(CrinosCosmetics.ownsBody(body)), oldLegs};
    }

    public static boolean hidden(Object visual) {
        if(visual==null) return false;
        try {
            Object script=Reflect.call(visual,"getScriptItem");
            if(script==null) return false;
            Object location=Reflect.call(script,"getBodyLocation");
            if(location==null) return false;
            String name=location.toString().toLowerCase(Locale.ROOT);
            // B42 typed ItemBodyLocation renders a namespace-qualified ID.
            int colon=name.lastIndexOf(':');
            if(colon>=0) name=name.substring(colon+1);
            if(name.startsWith("makeup_")) return true;
            // 0.4.69: eyewear and masks never fit the wolf head; hidden while
            // the Crinos cosmetics are on (hats and neck jewellery stay).
            if(isFaceGearLocation(name)) {
                faceGearHidden++;
                if(!loggedFaceGear) { loggedFaceGear=true; System.out.println("[WTAGarou Java][CrinosFit] worn eyewear/mask hidden on the Crinos head: "+name); }
                return true;
            }
            // 0.4.69: footwear has no mesh while the digitigrade legs are on
            // (filtered out of the population snapshot, the same path that
            // hides makeup; the item stays worn and keeps its stats).
            if(legsScope() && CrinosCosmetics.isFootwearLocation(name)) {
                footwearHidden++;
                if(!loggedFootwear) { loggedFootwear=true; System.out.println("[WTAGarou Java][CrinosFit] worn footwear hidden under the digitigrade legs: "+name); }
                return true;
            }
            // 0.4.71: trousers/shorts/skirts are hidden with the legs on (they
            // paint on the human hips and the digitigrade thighs cut through).
            if(legsScope() && CrinosCosmetics.isLegwearLocation(name)) {
                legwearHidden++;
                if(!loggedLegwear) { loggedLegwear=true; System.out.println("[WTAGarou Java][CrinosFit] worn legwear hidden on the digitigrade legs: "+name); }
                return true;
            }
            return false;
        } catch(ReflectiveOperationException | RuntimeException ignored) {
            return false;
        }
    }

    public static boolean isFaceGearLocation(String name) {
        if(name==null) return false;
        int colon=name.lastIndexOf(':');
        String n=(colon>=0?name.substring(colon+1):name).toLowerCase(Locale.ROOT);
        return n.equals("eyes") || n.equals("lefteye") || n.equals("righteye")
                || n.equals("mask") || n.equals("maskeyes") || n.equals("maskfull");
    }

    /** Native IsoPlayer.getItemVisuals fills a caller-owned temporary list. */
    public static void filterSnapshot(ItemVisuals snapshot) {
        if(enabled() && snapshot!=null) snapshot.removeIf(CrinosFaceVisuals::hidden);
    }
    /** Direct texture-init callers may supply a list populated outside this
     * scope. Substitute a filtered copy, never mutate the caller's list. */
    public static Object[] textureArguments(Object[] args) {
        if(!enabled() || args.length!=3 || !(args[1] instanceof ItemVisuals visuals)) return args;
        ItemVisuals filtered=bodySnapshot(visuals);
        if(filtered==visuals) return args;
        Object[] copy=args.clone();
        copy[1]=filtered;
        return copy;
    }
    /** Native HumanVisual.getBodyVisuals returns SAVED data: always COPY. */
    public static ItemVisuals bodySnapshot(ItemVisuals original) {
        if(!enabled() || original==null) return original;
        ItemVisuals copy=null;
        for(Object item:original) {
            if(hidden(item)) {
                if(copy==null) { copy=new ItemVisuals(); copy.addAll(original); }
                copy.remove(item);
            }
        }
        return copy==null ? original : copy;
    }
}
