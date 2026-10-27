package zombie.core.textures;

/** TEST ONLY: async shared-texture lookup fixture. Never bundled. */
public class Texture {
    public static final Texture blonde=new Texture();
    public static final Texture brown=new Texture();
    public static final Texture crinos=new Texture();
    public static final Texture mask=new Texture();
    public boolean ready=true;
    public boolean isReady() { return ready; }
    public static Texture getSharedTexture(String path,int flags) {
        if(flags!=4) throw new AssertionError("must retain native model texture flags");
        return getSharedTexture(path);
    }
    public static Texture getSharedTexture(String path) {
        if(path.startsWith("media/textures/Body/WTAGarou_Crinos")) return crinos;
        if(path.startsWith("media/textures/Body/Masks/")) return mask;
        if (path.equals("media/textures/Body/WTAGarou_Wolf_Brown.png")) return brown;
        if (!path.equals("media/textures/Body/WTAGarou_Wolf_Blonde.png"))
            throw new AssertionError("unexpected texture path: "+path);
        return blonde;
    }
}
