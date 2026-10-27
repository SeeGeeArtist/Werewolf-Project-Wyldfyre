# 0.4.75: October 19 hosted test, second round

## The big one: the server owns your body in multiplayer

Two things you saw pointed at the same engine fact: the silver burn landed
on your Left Foot while the knife wound was on the Right Thigh, and that
burn "healed pretty quick".

In Build 42 multiplayer `BodyDamage.Update()` returns immediately on a
client for a living player. The SERVER simulates every player's body,
applies PvP and zombie wounds to its own copy (`hitConsequences` ->
`DamageFromWeapon`), and pushes the whole BodyDamage back to the owning
client every 2 seconds and right after each wound. So anything the mod
wrote into your body on your client (the relayed silver burn, Crinos
regeneration, the Java damage-intake scaling) was overwritten within two
seconds. The 0.4.72 relay picked a random part because the victim's client
never sees the hit itself; that part was then wiped by the next push.

What moved to the server (hosted and dedicated alike; single player is
unchanged):

- Silver hits: `OnWeaponHitCharacter` fires on the server too, before the
  wound. The server snapshots the target's parts, and on the next tick burns
  every part whose health dropped or that gained a wound flag, applies the
  Garou silver damage multiplier to that part, pushes the body at once
  (`sendDamage`) and tells the victim's client (HUD line, growl). A hit the
  clothing absorbed burns nothing. The client relay is retired.
- Contact burns (worn silver): the server sweep already did these; the
  client no longer double-scans in multiplayer.
- Regeneration, acute-damage Rage, the armour refund: `WTAGarou.BodySweep`
  in the 10-tick server sweep.
- Health pool: without a Java agent on the server, the sweep refunds the
  untaken share of every acute part drop (Crinos keeps 40%, Glabro/Hispo
  65%). Honest limit: a single blast that kills outright in the same tick is
  beyond this, the engine dies before the sweep runs. Sub-lethal hits show
  the full number for up to ~170 ms, then the refund lands. Single player
  keeps the Java path (scaled before the hit lands).

Several burns at once: yes. Every wounded part of a hit burns (a shotgun
spread can light three parts), contact burns are per part, and the health
panel lists each one.

## Dress crash (the "Lua console")

The window that opened was the debugger with Break On Error, triggered by a
real error in the dress command, not a keybind; my earlier answer was
wrong. In multiplayer `ISGrabItemAction` only asks the server for a floor
item and completes at once; the item arrives later. `ISWearClothing` queued
straight behind it resolved the item by id in `start()`, found nothing and
crashed, which also killed the rest of the queue (hoodie picked up, not
worn). Floor items now wait for arrival (same item id) and are worn when
they land; 10 s timeout with a notice.

## Rage: the revert buffer

Shifting into Glabro or Hispo at exactly 20 Rage spends 20, lands on 0 and
reverted on the next tick even while Rage climbed. `Rage.DEPLETED_HOLD_S`
= 2 s: the dry revert needs Rage under 1 for two continuous seconds and
never fires within two seconds of a shift. Climbing back over 1 clears the
clock.

## Wolf with a gun: the bang

Vanilla's attack hook (`ISReloadWeaponAction.attackHook`) plays the shot
sound and raises the world noise BEFORE `DoAttack`, and only then did the
Java jaws rule swallow the press. The hook asks `canShoot` first; that is
now wrapped: paws cannot pull a trigger, the gun dry-clicks, no bang, no
noise, HUD refusal line.

## Sounds

- The Crinos countdown is the Beast in the Garou's head: it now plays
  through `playSoundImpl` (local only). Every shift sound stays public.
  Nothing else in the mod is private today; the Q callouts are deliberately
  public.
- Crinos hurt growl: `WolfSounds.PAIN_FORMS` adds Crinos (pain only) with
  `WTAGarou_CrinosGrowl`; Lupus barks, Hispo uses its bark. Drop whines etc.
  into `WolfSounds.BY_FORM.<form>.pain` when you have them.
- Voice pitch: the vanilla voice (pain grunts, exertion, shouts) follows
  the form through the engine's `CharacterVoicePitch` (creation slider,
  -100..100): Glabro/Hispo -45, Crinos -100, Homid/Lupus the recorded
  default. Each client pitches every copy it hears; the default is learned
  only in a base form so a shifted voice is never mistaken for it.

## Guide

Page six was the whole silver story in one page. It is now "Silver"
(fragments, rounds, forging) and "Silver nitrate" (coats, meter, vessels);
pages are capped at 1000 plain characters in tests and the panel is a bit
taller.

## Not from the mod

- The server shutting down: your console shows the child server reaching
  `process-status@terminated` with no reason on the client side. The
  server's own console (`~/Zomboid/Server/<name>` logs or the Logs zip)
  holds it. Send that next time it happens.
