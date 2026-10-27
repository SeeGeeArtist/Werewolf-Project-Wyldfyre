package wtagarou.visuals;

import java.util.*;

/** Read-only. Never loads/replaces nodes, sets variables or changes attacks. */
public final class CrinosAttackDiagnostics {
    public static String describe(Object character) {
        try {
            Object animator=Reflect.call(character,"getAdvancedAnimator");
            if(animator==null) return "animator=unavailable";
            Object set=Reflect.get(animator,"animSet");
            if(set==null) return "animSet=unavailable";
            StringBuilder out=new StringBuilder("set=").append(Reflect.get(set,"name"));
            Object statesValue=Reflect.get(set,"states");
            boolean loaded=false;
            if(statesValue instanceof Map<?,?> states) {
                Object shove=states.get("shove");
                if(shove!=null && Reflect.get(shove,"nodes") instanceof Iterable<?> nodes) {
                    out.append("; shoveNodes=[");
                    for(Object node:nodes) {
                        Object name=Reflect.get(node,"name");
                        if("WTAGarouCrinosClaw".equals(name)) loaded=true;
                        out.append(name).append(":").append(Reflect.get(node,"animName"))
                                .append("(conditionPriority=").append(Reflect.get(node,"conditionPriority")).append("),");
                    }
                    out.append("]");
                } else out.append("; shoveState=absent");
            }
            out.append("; customNodeLoaded=").append(loaded);
            out.append("; eligible=").append(Reflect.call(character,"getVariableBoolean",
                    String.class,"WTAGarouCrinosUnarmed"));
            out.append("; floor=").append(Reflect.call(character,"getVariableBoolean",
                    String.class,"AimFloorAnim"));
            String debug=String.valueOf(Reflect.call(animator,"GetDebug")).replace('\n','|').replace('\r',' ');
            out.append("; live=").append(debug.length()>1800 ? debug.substring(0,1800)+"..." : debug);
            return out.toString();
        } catch(ReflectiveOperationException | RuntimeException e) {
            return "diagnostic unavailable: "+e.getClass().getSimpleName();
        }
    }
}
