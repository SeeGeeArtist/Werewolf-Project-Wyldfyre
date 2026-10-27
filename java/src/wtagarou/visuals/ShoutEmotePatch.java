package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/**
 * 0.4.63: the Q shout / whisper (IsoGameCharacter.Callout(true) ->
 * playEmote("shout"), also the radial "shout" emote) plays NO animation in
 * Crinos: the human shout gesture does not fit the beast. The roar / growl
 * sound and text still come from CalloutPatch. Only the "shout" emote is
 * touched and only for characters whose voice profile asks for it
 * (WTAGarouJava.setShoutAnim(character, false)).
 */
@Patch(className="zombie.characters.IsoGameCharacter", methodName="playEmote", warmUp=true, strictMatch=true)
public final class ShoutEmotePatch {
    @Patch.OnEnter(skipOn=true)
    public static boolean enter(@Patch.This Object character, @Patch.Argument(0) String emote) {
        return StealthRuntime.suppressEmote(character, emote);
    }
}
