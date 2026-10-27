package wtagarou.visuals;
import me.zed_0xff.zombie_buddy.Patch;

/** 0.4.45: "/garou ..." typed into the Lua debug console (-debug). The
 *  console compiles the line as Lua, so a leading slash was a syntax error
 *  and none of the chat commands worked there (Oct 7 report). Before
 *  ProcessCommand reads the entry, rewrite "/garou rage 100" into the Lua
 *  call garou("rage 100") that WTAGarouDebug.lua already exposes. */
@Patch(className="zombie.ui.UIDebugConsole", methodName="ProcessCommand", warmUp=true)
public final class DebugConsolePatch {
    @Patch.OnEnter
    public static void enter(@Patch.This Object console) {
        try {
            Object box=Reflect.get(console, "commandLine");
            if (box==null) return;
            Object raw=Reflect.get(box, "internalText");
            if (!(raw instanceof String)) return;
            String rewritten=rewrite((String) raw);
            if (rewritten!=null) Reflect.set(box, "internalText", rewritten);
        } catch (Throwable failure) {
            System.err.println("[WTAGarou][Console] command rewrite failed: " + failure);
        }
    }

    /** Returns the Lua line for a "/garou ..." command, or null to leave the line alone. */
    // Advice is inlined into zombie.ui.UIDebugConsole: MUST be public.
    public static String rewrite(String line) {
        if (line==null) return null;
        String trimmed=line.trim();
        if (!trimmed.startsWith("/garou")) return null;
        String rest=trimmed.substring("/garou".length());
        if (!rest.isEmpty() && !Character.isWhitespace(rest.charAt(0))) return null;
        String body=rest.trim().replace("\\", "\\\\").replace("\"", "\\\"")
                .replace("\r", "\\r").replace("\n", "\\n");
        return "garou(\""+body+"\")";
    }
}
