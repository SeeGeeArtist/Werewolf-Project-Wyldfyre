# 0.4.76: the hosted server console, and lodged silver-tip bullets

## What the server console showed

`coop-console.txt` is the hosted child server's log: this is where
server-side Lua errors live, and the client console never shows them.

- One mod error, 1137 times: `handleWitnessCommand ... Object tried to
  call nil` at `WTAGarouWitness.lua:34`. Every 4 s the client in a
  supernatural form reports who can see it; when a witness was a player
  (your wife), the server tried `getPlayerFromUsername` (a client global)
  and then `getPlayerFromRealName` (does not exist). Fixed: names resolve
  through `getOnlinePlayers()` on the server. Effect in play was nil (a
  Garou witness is ignored anyway) but the error flood cost server time.
- The shutdown at the end was normal: `Host user disconnected, stopping
  the server`, then an orderly save. If the server ever stops while you
  are still in the game, this file will carry the reason.
- Everything else is vanilla noise (`IsoPropertyType.lookupOrDefaultStr`,
  `AdvancedAnimator ... visitFileFailed` on a missing actiongroups folder).

## Lodged silver-tip bullets

A silver round that stays in the body keeps burning until it is pulled.

- Marking: on the server (hosted/dedicated) or in single player, a ranged
  silver hit whose wounded part reports `haveBullet()` marks that part in
  `d.silverBullets`. A silver blade never marks (no bullet), even on a
  part that already holds a lead one.
- Burn: a small piece, so no contact ramp. The burn creeps up at 0.15 per
  second to a cap of 25 (the contact plateau is 75) and is re-lit at 0.5
  if it ever heals out while the bullet is in. The part keeps its silver
  burn mark, so regeneration is blocked there and never pushes the bullet
  out the way it does for an ordinary bullet. The engine's own lodged
  bullet damage ticks on top.
- Removal: the vanilla action (Pliers, Tweezers, Forceps, Suture Needle
  Holder, any item tagged REMOVE_BULLET) clears `haveBullet`; the next
  sweep drops the mark and the burn then heals like any other.
- Health panel: that part's line reads "- Lodged silver-tip bullet" in the
  silver colour instead of "- Lodged Bullet"; other parts and other lines
  stay vanilla. Works when looking at another player's panel.
- HUD notices: "A silver-tip bullet is lodged in your X. It burns until it
  is pulled." and "The silver-tip bullet is out of your X."
- Guide: one sentence on the Silver page.

Other debris in the engine: glass shards (`haveGlass`) from broken
windows and vehicle crashes, removed by hand or with tweezers. Glass is
the only other foreign body the engine models; it is not metal, so nothing
else can carry silver. Bullets are the only lodged metal.
