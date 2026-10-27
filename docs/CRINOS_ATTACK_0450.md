# 0.4.50: empty-handed Crinos swing and spiked-club impact

## Change contract

- Target: show a one-handed weapon swing instead of the standing unarmed Crinos
  shove pose, and use a verified spiked-club impact sound.
- Baseline: `63badef`, the 0.4.49 head/coat integration. Keep the user's fixed
  GLB and painted PNGs byte-for-byte.
- Must remain untouched: existing damage/Rage calculations, knockback,
  weapon stats, inventory, identity, wolf animations, corpse/grapple handling,
  stomps, HUD/controller fixes and multiplayer authority.
- Evidence still needed: native node selection, swing/contact timing, input
  responsiveness and two-client visibility/audio. This environment does not
  contain the user's installed game JAR or current native animation XML.

## Implementation

The only added player node is
`42/media/AnimSets/player/shove/WTAGarouCrinosClaw.xml`.
It uses `Bob_Attack1Hand01_Hit` when `WTAGarouCrinosUnarmed` is true and
`AimFloorAnim` is false. It does not replace a vanilla filename or modify
the shared one-handed-weapon node.

`WTAGarouCrinosAttack.lua` sets eligibility from the form already resolved by
`Visual.refresh`. For local players that is their current state; for observers
it is the existing validated visual snapshot. Both hands must be empty, the
character must be alive and outside a vehicle. Equipment events clear/restore
eligibility immediately; Visual.clear resets it on death/trait loss/stream-out.
This does not require Crinos cosmetics or the Java texture load to succeed.

The native `ShoveAnim` start/end flags remain, along with one
`AttackCollisionCheck` at 25% of the swing. That contact phase comes from the
one-handed animation template. Shove's 0.80 playback multiplier, melee delay
8 and upper-body blend mask are retained. Different clip lengths mean the
perceived swing duration still needs a live check.

This is deliberately a presentation change: the existing attack still uses
native shove mechanics and the mod's current damage hooks. It does NOT add
another hit, equip an invisible club, change bare-hands stats, turn shoves into
weapon damage, or add damage on the client. An explicit empty-handed shove
also uses this pose because it enters the same native standing-shove state.
Equipped weapons/items, ground stomps, grapples and other forms are excluded.

## Verified sound, without guessed paths

The selected sound is the **long spiked club** event `LongSpikedClubHit`,
registered as `SoundKey.LONG_SPIKED_CLUB_HIT` in the available Build 42.20.2
reference ([pinned SoundKey.java](https://raw.githubusercontent.com/Ketum-Git/PZ-Javacode/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/scripting/objects/SoundKey.java)).
No WAV/OGG path or invented FMOD bank path is added.

The local attacker's `OnHitZombie` callback plays this event only for standing,
empty-handed Crinos BareHands/shove contacts. It checks
`GameSounds.isKnownSound` first, which queries the registered sound map without
auto-creating a missing entry
([GameSounds.java](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/GameSounds.java)).
If the sound is not present in the installed version, it logs once and leaves
audio unchanged. Normal character playback is used; the custom OGG volume
correction is not applied to this native bank event.

No impact sound is fired from the animation itself, so a swing that misses is
silent apart from existing native cues. Remote callbacks do not start another
copy. Existing victim reactions are not globally suppressed. This update covers
zombie contact, not a separate new PvP/object-hit sound system.

The reference engine raises `OnHitZombie` with the zombie, attacker, body part
and weapon, including the unarmed path
([IsoZombie.java](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/characters/IsoZombie.java)).
Actual network audibility must still be checked with two clients.

## Animation evidence and verification

The standard swing name and 25% contact are present in the mirrored native
[1HDefault.xml](https://raw.githubusercontent.com/Niteghxst/Project-Zomboid-Media-Files/main/media/AnimSets/player/melee/1handed/1HDefault.xml),
also used by the repository's existing FasterAttackSpeed reference mod.
The shove flags, delay and blend mask are based on
[ShoveDefault.xml](https://raw.githubusercontent.com/Niteghxst/Project-Zomboid-Media-Files/main/media/AnimSets/player/shove/ShoveDefault.xml).
These mirrored templates are not claimed to be extracted from the user's
current installation. The available B42 engine supports additive XML nodes and
condition-priority selection
([AnimState.java](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/advancedanimation/AnimState.java),
[AnimNode.java](https://github.com/Ketum-Git/PZ-Javacode/blob/b4ebfd3e9f1858a295dabe433964b39c843d3ea7/PZ_42.20.2/zombie/core/skinnedmodel/advancedanimation/AnimNode.java)).

Tests cover all forms, both hand slots, death/vehicle/ground/grapple guards,
verified sound lookup and missing-event fallback, local-only audio, observer
snapshot routing and equipment changes. XML checks assert one collision,
balanced shove flags, movement unlock, no animation-triggered hit audio and
exactly one condition-gated player node rather than a global override.
These are static/fixture checks, not a claim of in-game rendering.
`bash tests/run.sh` and `bash java/test.sh` both passed for this update,
including 40 new attack eligibility/audio assertions and five new observer
integration checks. Java source/JAR, server Lua, all GLBs and all PNGs are
unchanged from 0.4.49.

## Focused playtest

1. Fully quit the game, pull `feature/cosmetic-model-swap`, and update the actual
   installed mod, including the NEW `42/media/AnimSets/player/shove/` file.
   Restart; Definitions/mod should report **0.4.50**, Java still **0.4.49**.
   No JAR rebuild is needed for this update.
2. In Crinos, empty both hands. Aim and attack a standing zombie: look for the
   one-handed swing and listen for the club impact on contact.
3. Swing at empty space: no club impact. Stomp a prone zombie: normal stomp.
4. Equip a weapon, or hold an item in either hand: existing behavior returns.
   Unequip both hands: the Crinos swing should return.
5. Check Homid shoves and Hispo/Lupus attacks are unchanged. Test corpse pickup
   and an interrupted swing to check movement is not left locked.
6. If possible, have a second client observe the Crinos swing and verify the
   impact plays once. Missing sound logs, unchanged shove pose, early/late
   contact or movement lock should be reported with the current console log.

If the game still selects the shove, inspect that installation's
`media/AnimSets/player/shove` and the animation debug node name before changing
damage or introducing a hidden weapon.
