package zombie;
/** TEST ONLY. */
public final class GameTime {
    private static final GameTime instance=new GameTime();
    public float multiplier=1;
    public static GameTime getInstance() { return instance; }
    public float getMultiplier() { return multiplier; }
}
