import java.util.*;
import wtagarou.visuals.*;

/** 0.4.64: after AdvancedAnimator.OnAnimDataChanged(false) the root anim
 * layer must be put back on the ActionContext's current state, otherwise
 * the animator forces "Idle" while the player is still in walk/run and
 * root-motion movement stops until the key is pressed again. Fakes mirror
 * only the public B42.20.2 signatures the runtime calls through Reflect. */
public class AnimatorRestoreTest {
    static int checks;
    static void check(boolean value,String why) { checks++; if(!value) throw new AssertionError(why); }

    public static class FakeState {
        final String name;
        public FakeState(String name) { this.name=name; }
        public String getName() { return name; }
    }
    public static class FakeContext {
        FakeState root; List<FakeState> children=new ArrayList<>();
        public FakeState getCurrentState() { return root; }
        public String getCurrentStateName() { return root==null?"idle":root.name; }
        public List<FakeState> getChildStates() { return children; }
    }
    public static class FakeAnimator {
        int dataChanged; boolean lastReload=true;
        final List<String> setStates=new ArrayList<>(); List<String> lastChildren;
        public void OnAnimDataChanged(boolean reload) { dataChanged++; lastReload=reload; }
        public void setState(String name, List<String> children) { setStates.add(name); lastChildren=children; }
    }
    public static class ProbeAnimator extends FakeAnimator {
        boolean orderedOk;
        @Override public void setState(String name, List<String> children) {
            orderedOk=dataChanged==1;
            super.setState(name,children);
        }
    }
    public static class OrderedCharacter {
        final FakeContext context=new FakeContext(); final ProbeAnimator probe=new ProbeAnimator();
        public FakeContext getActionContext() { return context; }
        public ProbeAnimator getAdvancedAnimator() { return probe; }
    }
    public static class NoContext {
        final FakeAnimator animator=new FakeAnimator();
        public FakeAnimator getAdvancedAnimator() { return animator; }
    }
    public static class FakeCharacter {
        final FakeContext context=new FakeContext(); final FakeAnimator animator=new FakeAnimator();
        public FakeContext getActionContext() { return context; }
        public FakeAnimator getAdvancedAnimator() { return animator; }
    }

    public static void main(String[] args) throws Exception {
        // Walking player: reset must be followed by setState("walk", [sub states]).
        FakeCharacter walking=new FakeCharacter();
        walking.context.root=new FakeState("walk");
        walking.context.children.add(new FakeState("aim"));
        walking.context.children.add(null);
        WolfRuntime.resetAnimData(walking);
        check(walking.animator.dataChanged==1,"OnAnimDataChanged still called once");
        check(!walking.animator.lastReload,"reload=false preserved (no setDefaultState)");
        check(walking.animator.setStates.equals(List.of("walk")),"root state restored: "+walking.animator.setStates);
        check(walking.animator.lastChildren.equals(List.of("aim")),"child states forwarded by name, nulls skipped");

        // Ordering: the restore must run after the reset, not before.
        OrderedCharacter ordered=new OrderedCharacter();
        ordered.context.root=new FakeState("run");
        WolfRuntime.resetAnimData(ordered);
        check(ordered.probe.setStates.equals(List.of("run")),"run state restored");
        check(ordered.probe.orderedOk,"setState ran after OnAnimDataChanged");

        // Action context without a root state: leave the animator alone
        // (vanilla restoreAnimatorStateToActionContext does the same).
        FakeCharacter fresh=new FakeCharacter();
        WolfRuntime.resetAnimData(fresh);
        check(fresh.animator.dataChanged==1,"reset still happens without a root state");
        check(fresh.animator.setStates.isEmpty(),"no setState when ActionContext has no current state");

        // A character lacking getActionContext must not break the reset.
        NoContext bare=new NoContext();
        WolfRuntime.resetAnimData(bare);
        check(bare.animator.dataChanged==1,"reset survives a missing ActionContext accessor");

        System.out.println("AnimatorRestoreTest: "+checks+" checks passed");
    }
}
