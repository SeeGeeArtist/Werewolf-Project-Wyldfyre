package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** The Q shout: wolf and Crinos forms bark, growl or roar instead of "Hey". */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="Callout", warmUp=true, strictMatch=true)
public final class CalloutPatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object character) {
        return StealthRuntime.callout(character);
    }
}
