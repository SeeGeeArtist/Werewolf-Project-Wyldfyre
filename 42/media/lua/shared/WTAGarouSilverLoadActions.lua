--[[
    WTAGarou - Load silver rounds: the timed actions (0.4.63)

    Shared so a dedicated server can instance them by Type (NetTimedAction
    looks the class up by name and calls Type.new with the fields named in
    new()'s parameter list).

    Both actions are vanilla reload actions with the ammunition swapped:

      WTAGarouLoadSilverAction          <- ISReloadWeaponAction
        tube / cylinder guns. Same animation, sounds, reload-speed rules,
        racking afterwards and "gun must be in the primary hand" rule as
        loading ordinary rounds (Oct 16 playtest: the 0.4.58 action played
        no animation or audio and did not need the gun equipped).

      WTAGarouLoadSilverMagazineAction  <- ISLoadBulletsInMagazine
        magazines. Same InsertBullets animation and per-round sounds.

    The only differences: the rounds taken are the matching silver type
    (WTAGarou.SilverAmmo.CATALOG) and the silver count in the gun's or
    magazine's mod data goes up with each round, which is what makes the
    shot silver later. Mixing is still refused (S.hasOrdinary).
]]

require "WTAGarouSilverAmmo"
require "TimedActions/ISReloadWeaponAction"
require "TimedActions/ISLoadBulletsInMagazine"

WTAGarou = WTAGarou or {}
local S = WTAGarou.SilverAmmo

local function paws(character)
    return WTAGarou.Paws and WTAGarou.Paws.isPaws and WTAGarou.Paws.isPaws(character) == true
end

local function silverTypeOf(target)
    return S.silverTypeFor(S.ammoKeyOf(target))
end

-- ---------------------------------------------------------------------------
-- Guns (tube / cylinder): ISReloadWeaponAction with silver rounds
-- ---------------------------------------------------------------------------
WTAGarouLoadSilverAction = ISReloadWeaponAction:derive("WTAGarouLoadSilverAction")

function WTAGarouLoadSilverAction:isValid()
    if paws(self.character) then return false end
    if isClient() and self.gun and self.gun.getID then
        self.gun = self.character:getInventory():getItemById(self.gun:getID()) or self.gun
    end
    if not self.gun then return false end
    -- vanilla rule: the gun is loaded from the primary hand
    if self.character:getPrimaryHandItem() ~= self.gun then return false end
    if not S.isDebugUnlimited(self.gun) and S.hasOrdinary(self.gun) then return false end
    return silverTypeOf(self.gun) ~= nil
end

-- vanilla initVars with the silver item type and the optional count cap
function WTAGarouLoadSilverAction:initVars()
    ISReloadWeaponAction.setReloadSpeed(self.character, false)
    local silverType = silverTypeOf(self.gun)
    if not silverType then return end
    local inv = self.character:getInventory()
    local ammoCount = inv:getItemCountRecurse(silverType)
    ammoCount = math.min(ammoCount, self.gun:getMaxAmmo() - self.gun:getCurrentAmmoCount())
    if type(self.count) == "number" and self.count > 0 then ammoCount = math.min(ammoCount, self.count) end
    if ammoCount <= 0 then return end
    local bullets = inv:getSomeType(silverType, ammoCount)
    if bullets and not bullets:isEmpty() then
        self.bullets = bullets
        self.ammoCount = ammoCount
    end
end

-- vanilla loadAmmo plus the silver count; the tail (rack / close / complete)
-- is vanilla 42.20.2 verbatim.
function WTAGarouLoadSilverAction:loadAmmo()
    if not self.bullets then return end
    if not self.bullets:isEmpty() and self.gun:getCurrentAmmoCount() < self.gun:getMaxAmmo() then
        local bullet = self.bullets:get(0)
        self.bullets:remove(bullet)
        self.character:getInventory():Remove(bullet)
        self.gun:setCurrentAmmoCount(self.gun:getCurrentAmmoCount() + 1)
        S.setCount(self.gun, S.count(self.gun) + 1)
        sendRemoveItemFromContainer(self.character:getInventory(), bullet)
        syncHandWeaponFields(self.character, self.gun)
    end
    if self.bullets:isEmpty() or self.gun:getCurrentAmmoCount() >= self.gun:getMaxAmmo() then
        self.character:clearVariable("isLoading")
        if not isServer() then
            if self.gun:haveChamber() and not self.gun:isRoundChambered() then
                ISTimedActionQueue.addAfter(self, ISRackFirearm:new(self.character, self.gun))
            end
            if self.gun:needToBeClosedOnceReload() then
                self:setAnimVariable("isLoading", false)
                self:setAnimVariable("isRacking", true)
                return
            end
        end
        if isServer() then
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    elseif self.gun:isInsertAllBulletsReload() then
        self:loadAmmo()
    end
end

function WTAGarouLoadSilverAction:new(character, gun, count)
    local o = ISReloadWeaponAction.new(self, character, gun)
    o.count = count
    return o
end

-- ---------------------------------------------------------------------------
-- Magazines: ISLoadBulletsInMagazine with silver rounds
-- ---------------------------------------------------------------------------
WTAGarouLoadSilverMagazineAction = ISLoadBulletsInMagazine:derive("WTAGarouLoadSilverMagazineAction")

function WTAGarouLoadSilverMagazineAction:isValid()
    if paws(self.character) then return false end
    if not self.magazine then return false end
    if not S.isDebugUnlimited(self.magazine) and S.hasOrdinary(self.magazine) then return false end
    -- the un-wrapped vanilla check (WTAGarouSilverAmmo wraps isValid to refuse
    -- ORDINARY rounds into a silver magazine; that wrapper must not see us)
    local base = ISLoadBulletsInMagazine.WTAGarou_silver_isValid or ISLoadBulletsInMagazine.isValid
    return base(self)
end

function WTAGarouLoadSilverMagazineAction:start()
    local silverType = silverTypeOf(self.magazine)
    if not silverType or not self.character:getInventory():containsWithModule(silverType) then
        self:forceStop()
        return
    end
    self.ammoCountStart = self.magazine:getCurrentAmmoCount()
    self.magazine:setJobDelta(0.0)
    self:setOverrideHandModels(nil, "GunMagazine")
    self:setActionAnim(CharacterActionAnims.InsertBullets)
    self:initVars()
    self.loadedThisLoop = false
    self.updateLoadBulletsTime = 0.0
    self.character:setVariable("UpdateLoadBulletsTime", 0.0)
end

function WTAGarouLoadSilverMagazineAction:isLoadFinished()
    local silverType = silverTypeOf(self.magazine)
    if not silverType then return true end
    if self.magazine:getCurrentAmmoCount() >= self.magazine:getMaxAmmo() then return true end
    if type(self.count) == "number" and self.count > 0
        and self.magazine:getCurrentAmmoCount() - (self.ammoCountStart or 0) >= self.count then
        return true
    end
    return not self.character:getInventory():containsWithModule(silverType)
end

-- vanilla animEvent with the silver type in the InsertBullet step
function WTAGarouLoadSilverMagazineAction:animEvent(event, parameter)
    if isServer() then
        if event == "updateLoadingTime" then self:updateLoadingTime() end
    end
    if event == "InsertBulletSound" then
        if self:isLoadFinished() then return end
        if self:isLocal() and self.loadedThisLoop then return end
        self.character:playSound(parameter)
    elseif event == "InsertBullet" then
        if self:isLoadFinished() then return end
        if self:isLocal() and self.loadedThisLoop then return end
        self.loadedThisLoop = true
        if not isClient() then
            local chance, xp = 5, 1
            if self.character:getPerkLevel(Perks.Reloading) < 5 then chance, xp = 2, 4 end
            if ZombRand(chance) == 0 then addXp(self.character, Perks.Reloading, xp) end
            local silverType = silverTypeOf(self.magazine)
            local removed = self.character:getInventory():RemoveOneOf(silverType, true)
            self.magazine:setCurrentAmmoCount(self.magazine:getCurrentAmmoCount() + 1)
            S.setCount(self.magazine, S.count(self.magazine) + 1)
            sendRemoveItemFromContainer(self.character:getInventory(), removed)
            syncItemFields(self.character, self.magazine)
        end
    elseif event == "loadFinished" then
        if self:isLoadFinished() then
            self.loadFinished = true
            self.loadedThisLoop = false
            if isServer() then self.netAction:forceComplete() end
        end
    elseif event == "playReloadSound" then
        if parameter == "insertAmmoStart" then
            if not self.playedInsertAmmoStartSound and self.magazine.getInsertAmmoStartSound
                and self.magazine:getInsertAmmoStartSound() then
                self.playedInsertAmmoStartSound = true
                self.character:playSound(self.magazine:getInsertAmmoStartSound())
            end
        end
    end
end

function WTAGarouLoadSilverMagazineAction:new(character, magazine, count)
    local o = ISLoadBulletsInMagazine.new(self, character, magazine, count)
    o.count = count
    return o
end
