# Existing-character werewolf opt-in

Lua-only follow-up on `feature/resolve-update`, November 7, 2026. This is an
implementation candidate, not a live-tested solo or multiplayer result.

## Change contract

- **Target:** grant the Werewolf trait bundle to an already played character,
  without returning to character creation or checking trait points.
- **Confirmed working:** no new gameplay confirmation. Earlier Resolve,
  moon-exposure and HUD commits are still awaiting the user's tests.
- **Request:** one-time opt-in for non-werewolves in solo and multiplayer;
  `/garou trait` must include Cat's Eyes, Fast Healer and Hearty Appetite.
- **Preserve:** learned levels/XP, other traits, Startup identity/auspice,
  moon exposure and +15 maximum bonus, Rage balance, Java, models and assets.
- **Evidence needed:** real save/reload, ordinary-role MP reconnect, native
  trait effects, prompt layout, controller focus and Startup handoff.

## Player behavior

On first loading a non-werewolf character with this update, the client asks
the authority whether to offer conversion. This is per character, not per
account or world. The native `OnNewGame` event suppresses the retrofit offer
for a freshly created human, preserving the choice just made at character
creation. That character can still opt in manually later.

- **Yes:** grant Werewolf, Cat's Eyes, Fast Healer and Hearty Appetite.
  Replace Slow Healer and Light Eater if present, as explained in the prompt.
  The existing HUD and Werewolf Startup hooks then handle the new Garou.
- **No:** keep the character human and save that decision, with no repeat
  automatic prompt after reload/reconnect. `/garou trait` can opt in later.
- **Disconnect before answering:** no decision is recorded, so the prompt
  can return. Sending an answer retries until the server replies.
- **Already a werewolf:** no automatic offer and no forced trait edits.
  Run `/garou trait` to repair a previous incomplete runtime grant.
- **Repeat grant:** add only missing traits, with no duplicate XP modifiers.
  The normal trait XP-boost map is updated, not earned levels or XP totals.
- **Remove:** `/garou untrait` remains privileged and removes Werewolf only.
  Companion traits stay; unrelated traits are never erased or recreated.

The runtime grant deliberately does not enforce all of the creation-screen
Garou exclusions on an established character. In particular it does not
change weight, erase literacy/asthma traits or reset trained physical skills.
The future Resolve/Wits/Gnosis auspice allocation is not applied here.

## Multiplayer authority and host controls

`WTAGarou.AllowWerewolfOptIn` defaults to true. The sandbox checkbox
“Allow existing-character werewolf opt-in” disables both automatic offers
and ordinary-player `/garou trait` grants when false. Existing accepted
conversions remain valid, and privileged debug grants still work.

The new request is self-only: it uses the player supplied to the server's
command handler, not any target, trait list, level or role sent by a client.
All other `Debug*` permissions are unchanged. The server changes native
traits first, records the decision in its retained player modData, and
replies to the owning player ID. Only then does that client mirror the same
native changes and refresh the character-info screen. Split-screen offers
and replies use the character's own viewport and recipient ID.

Registry/API failures are reported rather than setting a fake `isGarou`
flag. The bundle preflights all trait objects and attempts rollback on a
native error. Failed grants do not save an accepted decision.

## Engine evidence

Build 42.21's native `CharacterTraits.add/set` changes one membership and
does not expand `GrantedTraits`; `set(true)` appends to the known-trait list,
so membership checks are necessary to prevent duplicates
([CharacterTraits.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/characters/traits/CharacterTraits.java)).
The native `modifyTraitXPBoost` changes the descriptor's XP-boost map,
not existing perk levels or XP totals
([IsoGameCharacter.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/characters/IsoGameCharacter.java)).

Vanilla's admin trait UI uses `modifyTraitXPBoost` and `SyncXp`, but
`SyncXp` sends only when `GameClient.client` is true, not on the server;
the new path therefore uses its own addressed, server-approved reply instead
of assuming a server-side `SyncXp` call works
([vanilla UI](https://raw.githubusercontent.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/main/client/ISUI/PlayerStats/ISPlayerStatsUI.lua),
[LuaManager.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/Lua/LuaManager.java)).
The prompt uses the stock controller-capable dialog and its player-index
callback convention
([ISModalDialog.lua](https://raw.githubusercontent.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/main/client/ISUI/ISModalDialog.lua)).
The engine raises `OnNewGame(player, square)` for a new player after applying
creation traits; the new-character suppression queues its decision until
the first player update instead of transmitting during creation
([LuaManager.java](https://raw.githubusercontent.com/rbm4/apocalipsebr-zomboid-patches/4379818fb75b7c2395fb6a4edb0b93bc05d9b8a1/42.21.0/decompiled/zombie/Lua/LuaManager.java)).

## Verification and smallest playtest

Static coverage is in `tests/enrollment_test.lua`: full bundle, direct
conflicts, duplicate grants/removals, failed native mutations, saved No,
reconnect query, host switch, malformed/foreign-target requests, dead and
remote characters, ordinary/admin routes, split-screen routing, lost-answer
retry, stale recipient rejection, controller focus and trait-screen refresh.
These tests are fixtures, not proof of native multiplayer persistence.

Restart the game (and host/server) with this branch; Lua remains 0.5.0 and
Java remains 0.4.98. Use a backup/test save, because accepting changes traits.

1. Load an existing human in solo. Choose Yes; check all four traits, HUD
   and Startup. Compare earned skill levels and XP with the pre-grant values.
2. Save/reload. The four traits and Startup choices should remain, with no
   offer. Run `/garou trait` again through the debug console if desired;
   verify no repeated boost changes.
3. On a second human choose No, then reload. No trait changes and no repeated
   offer. The decision must not suppress the first offer on another character.
4. Repeat Yes and No with an ordinary `user` on a hosted multiplayer server.
   Reconnect, then restart the server and reconnect again. Check all four
   native traits, their effects and skill XP modifiers on both sides.
5. Test `/garou trait` as an ordinary MP user after No; it should grant the
   complete bundle. Turn the host option off and test on a different human:
   no automatic offer, and the command should report disabled.
6. Test two local characters: only the character answering Yes should change.
   On Steam Deck, A accepts and B declines; focus should return correctly.
7. Create a new human without Werewolf. There should be no retrofit prompt
   on that first spawn or after reload; manual opt-in should remain available.

On failure keep both client `console.txt` and host `coop-console.txt`, with
`[WTAGarou][Enrollment]` messages and the native character-trait screen.
