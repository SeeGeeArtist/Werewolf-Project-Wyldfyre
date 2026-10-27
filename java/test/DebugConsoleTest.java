import wtagarou.visuals.DebugConsolePatch;
import java.lang.reflect.Method;

/** 0.4.45: "/garou ..." in the Lua debug console becomes garou("..."). */
public final class DebugConsoleTest {
    public static class Box { public String internalText; }
    public static class Console {
        public Box commandLine = new Box();
        public String compiled;
        public void ProcessCommand() { compiled = commandLine.internalText; }
    }
    public static void main(String[] args) throws Exception {
        var inst = net.bytebuddy.agent.ByteBuddyAgent.install();
        WolfCombatTest.install(inst, Console.class, DebugConsolePatch.class, "ProcessCommand");
        Console console = new Console();
        console.commandLine.internalText = "/garou reload";
        console.ProcessCommand();
        assert "garou(\"reload\")".equals(console.compiled) : "woven advice must rewrite from another package";
        Method rewrite=DebugConsolePatch.class.getDeclaredMethod("rewrite", String.class);
        rewrite.setAccessible(true);
        assert "garou(\"rage 100\")".equals(rewrite.invoke(null, "/garou rage 100"));
        assert "garou(\"cheats\")".equals(rewrite.invoke(null, "  /garou   cheats  "));
        assert "garou(\"\")".equals(rewrite.invoke(null, "/garou"));
        assert "garou(\"form \\\"Hispo\\\"\")".equals(rewrite.invoke(null, "/garou form \"Hispo\""));
        assert rewrite.invoke(null, "garou(\"rage 100\")")==null : "plain Lua is left alone";
        assert rewrite.invoke(null, "/garoux rage")==null : "other slash words are left alone";
        assert rewrite.invoke(null, "print(1)")==null;
        assert rewrite.invoke(null, (Object) null)==null;
        System.out.println("PASS: /garou console lines rewrite to garou(\"...\"); everything else untouched.");
    }
}
