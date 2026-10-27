package zombie.characters;

/** Test stand-in for the engine's stat registry: only the field TraitsRuntime looks up. */
public final class CharacterStat {
    public static final CharacterStat POISON = new CharacterStat("Poison");
    public final String name;
    private CharacterStat(String name) { this.name = name; }
}
