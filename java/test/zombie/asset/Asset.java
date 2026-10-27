package zombie.asset;
/** TEST ONLY. */
public class Asset {
    public boolean ready, failed;
    public boolean isReady() { return ready && !failed; }
    public boolean isFailure() { return failed; }
    public String getState() { return failed ? "FAILURE" : ready ? "READY" : "EMPTY"; }
}
