--[[
    WTAGarou - Hand slot rules and mouth carry (v0.4.17)

    Lore rule, per form:
      Homid / Glabro / Crinos  two hands, business as usual.
      Hispo / Lupus            the PRIMARY slot is the jaws: one item under
                               the form weight cap carried in the mouth and
                               swung around like the Sif fight. 0.4.20:
                               firearms may be carried but never fired.

    0.4.17 (user request, September 26): the SECONDARY slot and two-handed
    items are no longer stripped from wolf forms (allowSecondaryHand = true
    on Hispo and Lupus). The primary/jaws rules are unchanged: the item in
    the primary slot still has to pass canEquipPrimary (weight, no firearms),
    and two-handed items occupy both slots exactly as the engine does it.

    Implementation:
      * The jaws item is flagged in mod data so other systems (attack code,
        attachment points, drop-on-yelp behaviour) can find it.
      * Setting allowSecondaryHand back to false on a form restores the old
        "no off-hand" behaviour; nothing else changes.

    Containers are untouched. A wolf is smaller than a person but the whole
    point of the saddlebag is that it can still haul gear, so worn containers
    stay equipped through a shift.
]]

WTAGarou = WTAGarou or {}
WTAGarou.Slots = WTAGarou.Slots or {}

local MOUTH_KEY = "WTAGarou_MouthItem"

local function unequip(player, item)
    if not item then return end
    -- setPrimary/SecondaryHandItem(nil) is the low-level unequip. The item
    -- stays in the inventory; it just leaves the hand.
    pcall(function()
        if player:getPrimaryHandItem() == item then player:setPrimaryHandItem(nil) end
        if player:getSecondaryHandItem() == item then player:setSecondaryHandItem(nil) end
        if item.setAttachedSlot then item:setAttachedSlot(-1) end
    end)
end

--- Can this form hold anything in its jaws, and how heavy?
function WTAGarou.Slots.mouthLimit(formName)
    local fd = WTAGarou.GetForm(formName)
    if not fd.mouthCarry then return nil end
    return fd.mouthCarryMaxWeight or 0
end

--- May `item` go into the primary hand while in `formName`?
function WTAGarou.Slots.canEquipPrimary(player, item, formName)
    formName = formName or WTAGarou.GetData(player).form
    local fd = WTAGarou.GetForm(formName)

    if fd.allowPrimaryHand then return true end

    -- No hands. Jaws only.
    if not fd.mouthCarry then return false, "no_hands" end
    if not item then return false, "no_hands" end

    local w = item.getActualWeight and item:getActualWeight() or (item:getWeight() or 0)
    if w > (fd.mouthCarryMaxWeight or 0) then
        return false, "too_heavy_for_jaws"
    end

    -- 0.4.20: a wolf CAN carry a rifle in its jaws (the 0.4.19 playtest
    -- unequipped one instantly and detached it from the back); it just
    -- cannot work the trigger. Firing is swallowed on the Java side
    -- (JawsAttackPatch) while the direct wolf body is active.
    return true
end

--- May `item` go into the secondary/off-hand while in `formName`?
function WTAGarou.Slots.canEquipSecondary(player, item, formName)
    formName = formName or WTAGarou.GetData(player).form
    local fd = WTAGarou.GetForm(formName)
    if fd.allowSecondaryHand then return true end
    return false, "no_offhand"
end

--- Force the character's hands to obey the rules for `formName`.
-- Safe to call every tick and safe to call mid-shift.
function WTAGarou.Slots.enforce(player, formName)
    if not player then return end
    formName = formName or WTAGarou.GetData(player).form
    local fd = WTAGarou.GetForm(formName)
    local md = player:getModData()

    if fd.allowPrimaryHand and fd.allowSecondaryHand then
        md[MOUTH_KEY] = nil
        return
    end

    local primary   = player:getPrimaryHandItem()
    local secondary = player:getSecondaryHandItem()

    -- The off-hand is simply gone for quadrupeds.
    if not fd.allowSecondaryHand and secondary then
        unequip(player, secondary)
    end

    if not fd.allowPrimaryHand then
        if primary then
            local ok = WTAGarou.Slots.canEquipPrimary(player, primary, formName)
            if ok then
                -- Legal jaws carry. Record it so attack / attachment code can
                -- render it at the muzzle bone rather than in a hand.
                md[MOUTH_KEY] = primary:getFullType()
            else
                unequip(player, primary)
                md[MOUTH_KEY] = nil
            end
        else
            md[MOUTH_KEY] = nil
        end
    end
end

--- The item currently held in the jaws, or nil.
function WTAGarou.Slots.getMouthItem(player)
    if not player then return nil end
    local fd = WTAGarou.GetForm(WTAGarou.GetData(player).form)
    if not fd.mouthCarry then return nil end
    return player:getPrimaryHandItem()
end

function WTAGarou.Slots.isQuadruped(player)
    if not player then return false end
    return WTAGarou.GetForm(WTAGarou.GetData(player).form).quadruped == true
end

-- ---------------------------------------------------------------------------
-- Continuous enforcement.
-- The player can always drag an item into a hand slot through the inventory
-- UI, so a poll is the only way to be sure the rule holds.
-- ---------------------------------------------------------------------------
if not isServer() then
    local tick = 0
    Events.OnPlayerUpdate.Add(function(player)
        if not player or player:isDead() then return end
        tick = tick + 1
        if tick % 15 ~= 0 then return end
        WTAGarou.Slots.enforce(player, nil)
    end)
end
