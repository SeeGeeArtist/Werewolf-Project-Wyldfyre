package zombie.core.skinnedmodel.model;
/** TEST ONLY. Small enum fixture, not a replacement engine class. */
public class CharacterMask {
    public enum BloodPart {
        Head, Chest;
        public int index() { return ordinal(); }
    }
    public enum Part {
        Head,Chest,Dress,LeftLeg,LeftFoot,RightLeg,RightFoot;
        public static Part[] leaves() { return values(); }
        public BloodPart[] getBloodBodyPartTypes() {
            return this==Dress ? new BloodPart[0]
                    : new BloodPart[]{this==Head ? BloodPart.Head : BloodPart.Chest};
        }
    }
    public boolean head=true,chest=true,dress=true;
    public final java.util.EnumSet<Part> hiddenLegs=java.util.EnumSet.noneOf(Part.class);
    public void setPartVisible(Part p,boolean visible) {
        if(p==Part.Head) head=visible; else if(p==Part.Dress) dress=visible; else if(p==Part.Chest) chest=visible;
        else { if(visible) hiddenLegs.remove(p); else hiddenLegs.add(p); }
    }
    public boolean isPartVisible(Part p) {
        return p==Part.Head ? head : p==Part.Dress ? dress : p==Part.Chest ? chest : !hiddenLegs.contains(p);
    }
}
