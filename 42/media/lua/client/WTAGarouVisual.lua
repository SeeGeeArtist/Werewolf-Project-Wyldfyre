-- WTAGarou 0.4.4: independent scaling plus direct Java body/clip prototype.
require "WTAGarouDefinitions"
require "WTAGarouWolfCoats"
require "WTAGarouWolfGear"
require "WTAGarouCrinosAttack"
WTAGarou.Visual = WTAGarou.Visual or {}
local Visual = WTAGarou.Visual

-- Object keys, NOT online IDs (single-player players share onlineID=-1).
local applied = setmetatable({}, { __mode = "k" })
local originals = setmetatable({}, { __mode = "k" })
local scales = setmetatable({}, { __mode = "k" })
local warnedJava = false
local wolfStates = setmetatable({}, { __mode = "k" })
local warnedWolfJava = false
local remoteStates = setmetatable({}, { __mode = "k" })
local crinosStates = setmetatable({}, { __mode = "k" })

-- 0.4.59: "pending" used to wait a full second between asks, which is the
-- "big guy in underwear" moment after the first Crinos/wolf channel. Assets
-- are now preloaded at player creation (Visual.preload) and a pending answer
-- is re-asked every PENDING_RETRY_S, giving up after PENDING_GIVE_UP_S.
Visual.PENDING_RETRY_S = 0.1
Visual.PENDING_GIVE_UP_S = 60
local function nowSeconds()
    if getTimestampMs then
        local ok, ms = pcall(getTimestampMs)
        if ok and type(ms) == "number" then return ms / 1000 end
    end
    return getTimestamp()
end
Visual.nowSeconds = nowSeconds

local function coatTextures(coat)
    local entry=(WTAGarou.WolfCoats or {})[coat] or WTAGarou.WolfCoats.default
    local fallback=WTAGarou.WolfCoats.default
    return entry.crinosBody or fallback.crinosBody, entry.crinosHead or fallback.crinosHead, entry.path or fallback.path
end
-- 0.4.67: digitigrade legs are part of every Crinos; the tail is the
-- player's choice (data.crinosTail, synced in the VisualSnapshot rows for
-- remote players). Returns legs, tail ("" = none) for the coat.
local function coatParts(coat, tailOn)
    local entry=(WTAGarou.WolfCoats or {})[coat] or WTAGarou.WolfCoats.default
    local fallback=WTAGarou.WolfCoats.default
    local legs=entry.crinosLegs or fallback.crinosLegs or ""
    local tail=tailOn and (entry.crinosTail or fallback.crinosTail) or ""
    return legs, tail
end
Visual.coatParts = coatParts
local function tailWanted(player)
    local remote = remoteStates[player]
    if remote then return WTAGarou.CrinosTailOn(remote.crinosTail) end
    local md = player.getModData and player:getModData() or {}
    return WTAGarou.CrinosTailOn(md.WTAGarou and md.WTAGarou.crinosTail)
end
Visual.tailWanted = tailWanted

local function refreshCrinos(player,form,coat,force)
    if not (WTAGarouJava and WTAGarouJava.setCrinosCosmetics) then return end
    local body,head=coatTextures(coat)
    local legs,tail=coatParts(coat, tailWanted(player))
    local parts=WTAGarouJava.setCrinosCosmeticsParts~=nil
    if not parts then legs,tail="","" end
    local enabled=WTAGarou.EnableCrinosCosmetics == true and form=="Crinos"
    local key=tostring(enabled)..":"..tostring(body)..":"..tostring(head)..":"..legs..":"..tail
    local state=crinosStates[player]
    local now=nowSeconds()
    if not force and state and state.key==key then
        if state.result~="pending" or now<state.retry then return end
        if now-state.firstAt>=Visual.PENDING_GIVE_UP_S then return end
    end
    local ok,result
    if parts then
        ok,result=pcall(WTAGarouJava.setCrinosCosmeticsParts,player,enabled,body,head,legs,tail)
    else
        ok,result=pcall(WTAGarouJava.setCrinosCosmetics,player,enabled,body,head)
    end
    if not ok then result="failed" end
    local same=(state and state.key==key and not force)
    crinosStates[player]={key=key,result=result,retry=now+Visual.PENDING_RETRY_S,
        attempts=same and state.attempts+1 or 1, firstAt=same and state.firstAt or now}
    if not state or state.key~=key or state.result~=result then
        print("[WTAGarou][CrinosCosmetics] "..key.." -> "..tostring(result))
    end
end
Visual.refreshCrinos = refreshCrinos

-- 0.4.59: warm the wolf model, Crinos head and this coat's textures as soon
-- as a Garou player exists, so the first shift finds them resident. Polled
-- from Visual.refresh until "ready"; logs once per outcome.
local preloadStates = {}
local function preload(player, coat)
    if not (WTAGarouJava and WTAGarouJava.preloadForms) then return nil end
    local body,head,path=coatTextures(coat)
    local key=tostring(body)..":"..tostring(head)..":"..tostring(path)
    local state=preloadStates[player]
    local now=nowSeconds()
    if state and state.key==key then
        if state.result~="pending" or now<state.retry then return state.result end
        if now-state.firstAt>=Visual.PENDING_GIVE_UP_S then return state.result end
    end
    local ok,result=pcall(WTAGarouJava.preloadForms,body,head,path)
    if not ok then result="failed" end
    -- 0.4.67: legs + tail meshes and this coat's part textures too (both
    -- warmed even when the tail is off, so toggling it later is instant).
    if result=="ready" and WTAGarouJava.preloadCrinosParts then
        local legs,tail=coatParts(coat,true)
        local female=player.isFemale and player:isFemale()==true
        local okParts,partsResult=pcall(WTAGarouJava.preloadCrinosParts,legs,tail,female)
        if not okParts or partsResult~="ready" then result=okParts and partsResult or "failed" end
    end
    local same=(state and state.key==key)
    preloadStates[player]={key=key,result=result,retry=now+Visual.PENDING_RETRY_S,
        firstAt=same and state.firstAt or now}
    if not state or state.key~=key or state.result~=result then
        local took=string.format("%.1f", now-preloadStates[player].firstAt)
        print("[WTAGarou][Preload] wolf + Crinos assets "..tostring(result).." ("..took.." s) for "..key)
    end
    return result
end
Visual.preload = preload

local function refreshWolf(player, wanted, force)
    if not WTAGarouJava or not WTAGarouJava.setWolf then
        if wanted and not warnedWolfJava then
            warnedWolfJava = true
            print("[WTAGarou] Direct wolf needs Java 0.4.4; approve the updated JAR and restart.")
        end
        return
    end
    local state = wolfStates[player]
    local now = nowSeconds()
    if not force and state and state.wanted == wanted then
        if state.result ~= "pending" or now < state.retryAt then return end
        if now - (state.firstAt or now) >= Visual.PENDING_GIVE_UP_S then return end
    end
    local attempts = (state and state.wanted == wanted and not force) and state.attempts + 1 or 1
    local firstAt = (state and state.wanted == wanted and not force) and (state.firstAt or now) or now
    -- 0.4.17: push the mouth-carry switch and the jaw item rotation/offset
    -- (WTAGarou.MouthCarry) before every wolf request so a Definitions edit
    -- takes effect on the next shift without a Java rebuild.
    if wanted then
        pcall(function()
            if WTAGarouJava.setMouthCarry then WTAGarouJava.setMouthCarry(WTAGarou.EnableMouthCarry ~= false) end
            local mc = WTAGarou.MouthCarry or {}
            local r, o = mc.rotate or {}, mc.offset or {}
            if WTAGarouJava.setMouthCarryTransform then
                WTAGarouJava.setMouthCarryTransform(r[1] or 0, r[2] or 0, r[3] or 0, o[1] or 0, o[2] or 0, o[3] or 0)
            end
            -- 0.4.22: saddlebag post-transform and gait slowdown, same path.
            local sb = WTAGarou.Saddlebag or {}
            local sr, so = sb.rotate or {}, sb.offset or {}
            if WTAGarouJava.setSaddlebagTransform then
                WTAGarouJava.setSaddlebagTransform(sr[1] or 0, sr[2] or 0, sr[3] or 0, so[1] or 0, so[2] or 0, so[3] or 0)
            end
            if WTAGarouJava.setSaddlebagScale then WTAGarouJava.setSaddlebagScale(sb.scale or 1) end
            -- Skinned harness uses the wolf's bind space, never rigid offsets.
            if WTAGarouJava.setAttachmentPivot then
                for key, cfg in pairs({mouth=mc, saddlebag=sb}) do
                    local p = cfg.pivot or {}
                    WTAGarouJava.setAttachmentPivot(key, p[1] or 0, p[2] or 0, p[3] or 0)
                end
            end
            Visual.pushWolfSlots(player)
            if WTAGarouJava.setGaitSlowdown then
                WTAGarouJava.setGaitSlowdown(((WTAGarou.WolfGait or {}).CYCLE_SLOWDOWN) or 1)
            end
            if WTAGarouJava.setWolfAttackSpeed then
                WTAGarouJava.setWolfAttackSpeed(((WTAGarou.WolfGait or {}).ATTACK_SPEED) or 1.5)
            end
            if WTAGarouJava.setWolfStompSpeed then
                WTAGarouJava.setWolfStompSpeed(((WTAGarou.WolfGait or {}).STOMP_SPEED) or 1.0)
            end
            if WTAGarouJava.setMarkerAtOrigin then
                WTAGarouJava.setMarkerAtOrigin(((WTAGarou.WolfGait or {}).MARKER_AT_ORIGIN) == true)
            end
            if WTAGarouJava.setTransitionsKeepHumanTiming then
                WTAGarouJava.setTransitionsKeepHumanTiming(((WTAGarou.WolfGait or {}).TRANSITIONS_KEEP_HUMAN_TIMING) ~= false)
            end
        end)
    end
    local result = WTAGarouJava.setWolf(player, wanted)
    wolfStates[player] = {wanted=wanted, result=result, retryAt=now+Visual.PENDING_RETRY_S, attempts=attempts, firstAt=firstAt}
    if not state or state.result ~= result or state.wanted ~= wanted then
        print("[WTAGarou] Direct wolf request=" .. tostring(wanted) .. " result=" .. tostring(result))
    end
    if result == "pending" and attempts == 60 then
        print("[WTAGarou] Wolf assets still unavailable after 60 attempts; keeping human body. /garou wolf on retries.")
    end
end

local stabilities = {}
local poises = setmetatable({}, { __mode = "k" })     -- 0.4.68
local intakes = setmetatable({}, { __mode = "k" })    -- 0.4.72
local voicePitches = setmetatable({}, { __mode = "k" }) -- 0.4.75
local tallFlags = setmetatable({}, { __mode = "k" })  -- 0.4.68
local crowdRules = setmetatable({}, { __mode = "k" }) -- 0.4.69
local stealthForms = {}

-- 0.4.23: the engine attachment name behind a hotbar LOCATION id ("Back" ->
-- whatever AttachedLocations.lua registered). nil when unknown.
local function slotAttachmentName(player, locationId)
    local ok, name = pcall(function()
        local attached = player and player.getAttachedItems and player:getAttachedItems() or nil
        local group = attached and attached.getGroup and attached:getGroup() or nil
        local loc = group and group.getLocation and group:getLocation(locationId) or nil
        return loc and loc.getAttachmentName and loc:getAttachmentName() or nil
    end)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end
Visual.slotAttachmentName = slotAttachmentName

-- Every WTAGarou.WolfSlots rule as {key, bone, rotate, offset}, once per
-- attachment name: the location id resolved through the engine when
-- possible, plus the raw key so a rule written with the attachment name
-- itself (or "secondary") also lands.
local function wolfSlotRules(player)
    local cfg = WTAGarou.WolfSlots or {}
    local rules, seen = {}, {}
    for key, rule in pairs(cfg) do
        if type(key) == "string" and type(rule) == "table" then
            local r, o, c = rule.rotate or {}, rule.offset or {}, rule.pivot or {}
            local bone = rule.bone or cfg.BONE or "Bip01_Spine2"
            local names = { key }
            local resolved = key ~= "secondary" and slotAttachmentName(player, key) or nil
            if resolved and resolved ~= key then table.insert(names, resolved) end
            -- Native hotbar items may have a type-specific attached location
            -- (Meat Cleaver Right, etc). Map its actual model attachment back
            -- to the configured hotbar slot, instead of guessing every name.
            if key ~= "secondary" then pcall(function()
                local attached=player:getAttachedItems()
                for i=0,attached:size()-1 do
                    local entry=attached:get(i)
                    local item=entry:getItem()
                    local slot=item and item.getAttachedSlotType and item:getAttachedSlotType()
                    if type(slot)=="string" and slot:lower()==key:lower() then
                        local alias=slotAttachmentName(player,entry:getLocation())
                        if alias then names[#names+1]=alias end
                    end
                end
            end) end
            for _, name in ipairs(names) do
                if not seen[name] then
                    seen[name] = true
                    table.insert(rules, { key = name, bone = bone,
                        rotate = { r[1] or 0, r[2] or 0, r[3] or 0 },
                        offset = { o[1] or 0, o[2] or 0, o[3] or 0 },
                        pivot  = { c[1] or 0, c[2] or 0, c[3] or 0 } })
                end
            end
        end
    end
    table.sort(rules, function(a, b) return a.key < b.key end)
    return rules
end
Visual.wolfSlotRules = wolfSlotRules

function Visual.pushWolfSlots(player)
    if not (WTAGarouJava and WTAGarouJava.setWolfSlot) then return 0 end
    local cfg = WTAGarou.WolfSlots or {}
    if WTAGarouJava.setWolfSlotsEnabled then WTAGarouJava.setWolfSlotsEnabled(cfg.ENABLED ~= false) end
    if WTAGarouJava.clearWolfSlots then WTAGarouJava.clearWolfSlots() end
    local rules = wolfSlotRules(player)
    for _, rule in ipairs(rules) do
        WTAGarouJava.setWolfSlot(rule.key, rule.bone, rule.rotate[1], rule.rotate[2], rule.rotate[3],
            rule.offset[1], rule.offset[2], rule.offset[3])
        -- 0.4.24: grip point (a separate call, so the 8-argument setWolfSlot
        -- keeps one signature for Kahlua).
        if WTAGarouJava.setWolfSlotPivot and (rule.pivot[1] ~= 0 or rule.pivot[2] ~= 0 or rule.pivot[3] ~= 0) then
            WTAGarouJava.setWolfSlotPivot(rule.key, rule.pivot[1], rule.pivot[2], rule.pivot[3])
        end
    end
    return #rules
end

-- Per-form noise / sight / voice profile pushed to the Java StealthRuntime.
-- Registered for the local player AND synced remotes so zombies simulated on
-- this client treat every Garou by its real form.
local function applyStealth(player, form)
    if not (WTAGarouJava and WTAGarouJava.setNoise) then return end
    if stealthForms[player] == form then return end
    stealthForms[player] = form
    local st = (WTAGarou.Stealth or {})[form] or {}
    local voice = (WTAGarou.Voice or {})[form]
    local wolf = (WTAGarou.WolfSounds and WTAGarou.WolfSounds.FORMS or {})[form] == true
    pcall(function()
        -- stepSound: wolf forms replace the human bank with it; 0.4.67 human-
        -- step forms layer it under the surface step (Crinos bass impact).
        local stepSound = ""
        if st.wolfSteps then
            stepSound = WTAGarou.Stealth.STEP_SOUND or ""
        elseif st.stepLayer then
            stepSound = st.stepLayer
        end
        WTAGarouJava.setNoise(player, st.footstepMul or 1.0, st.spotMul or 1.0,
            st.spotMulSneaking or 1.0, st.wolfSteps == true, stepSound)
        if voice then
            WTAGarouJava.setVoice(player, voice.standing or "", voice.crouched or "",
                voice.radiusStanding or 30, voice.radiusCrouched or 6)
            WTAGarouJava.setVoiceText(player, voice.textStanding or "", voice.textCrouched or "")
        else
            WTAGarouJava.setVoice(player, "", "", 30, 6)
            WTAGarouJava.setVoiceText(player, "", "")
        end
        -- 0.4.63: Crinos shouts and whispers without the human gesture
        if WTAGarouJava.setShoutAnim then
            WTAGarouJava.setShoutAnim(player, not (voice and voice.shoutAnim == false))
        end
        WTAGarouJava.setFallSound(player, wolf and WTAGarou.WolfSounds.fall or "")
    end)
    print("[WTAGarou] stealth/voice requested form=" .. tostring(form)
        .. " footstep=" .. tostring(st.footstepMul or 1.0) .. " spot=" .. tostring(st.spotMul or 1.0)
        .. " voice=" .. tostring(voice and voice.standing or "human"))
end

-- Body traits (raw-meat immunity, paw/barefoot immunity, per-gait speed and
-- turn multipliers) live in the Java TraitsRuntime. Client-side like the
-- stealth profile: in SP the Java runtime is in this process, and these are
-- exactly the engine paths (IsoPlayer.updateFootInjuries/updateMovementRates,
-- IsoGameCharacter.getTurnDelta, BodyDamage.JustAteFood) that run there.
local traitsApplied = setmetatable({}, { __mode = "k" })
local bulkFlags = setmetatable({}, { __mode = "k" })
local grappleForward = setmetatable({}, { __mode = "k" })
local shoulderPickup = setmetatable({}, { __mode = "k" })
local meleeRange = setmetatable({}, { __mode = "k" })
local warnedTraits = false
local function applyTraits(player, form, force)
    if not (WTAGarou.Traits and WTAGarou.TraitsFor) then return end
    if not (WTAGarouJava and WTAGarouJava.setTraits) then
        if not warnedTraits and WTAGarouJava and WTAGarouJava.setScale then
            warnedTraits = true
            print("[WTAGarou] Java traits unavailable (old WTAGarouVisuals.jar?): raw meat, paws and wolf speed keep vanilla rules.")
        end
        return
    end
    local t = WTAGarou.TraitsFor(form)
    local garou = WTAGarou.HasGarouTrait and WTAGarou.HasGarouTrait(player)
    if garou == nil then garou = true end
    local rawMeat = garou and WTAGarou.Traits.RawMeatImmune == true
    local paws = garou and t.paws == true
    -- 0.4.60: stride only matters for the Garou's own scaled bipeds; a
    -- non-Garou (or an old jar without setStride) keeps vanilla root motion.
    local stride = (garou and t.stride) or 1.0
    local key = table.concat({ tostring(rawMeat), tostring(paws), tostring(t.walk), tostring(t.run),
        tostring(t.sprint), tostring(t.sneak), tostring(t.turn), tostring(stride) }, "|")
    if not force and traitsApplied[player] == key then return end
    local ok, res = pcall(function()
        local accepted = WTAGarouJava.setTraits(player, rawMeat, paws,
            t.walk or 1.0, t.run or 1.0, t.sprint or 1.0, t.sneak or 1.0, t.turn or 1.0)
        if WTAGarouJava.setStride then WTAGarouJava.setStride(player, stride) end
        return accepted
    end)
    if ok and res ~= false then
        traitsApplied[player] = key
        print("[WTAGarou] traits requested form=" .. tostring(form) .. " rawMeat=" .. tostring(rawMeat)
            .. " paws=" .. tostring(paws) .. " walk=" .. tostring(t.walk) .. " run=" .. tostring(t.run)
            .. " sprint=" .. tostring(t.sprint) .. " sneak=" .. tostring(t.sneak) .. " turn=" .. tostring(t.turn)
            .. " stride=" .. tostring(stride))
    elseif not ok then
        print("[WTAGarou] traits request failed: " .. tostring(res))
    end
end
Visual.applyTraits = applyTraits

-- Does the player wear any container (bag, sling, satchel ...)?
local function wearsContainer(player)
    local found = false
    pcall(function()
        local worn = player:getWornItems()
        if not worn then return end
        for i = 0, worn:size() - 1 do
            local w = worn:get(i)
            local item = w and w:getItem() or nil
            if item and WTAGarou.Clothing and WTAGarou.Clothing.isContainer(item) then
                found = true
                return
            end
        end
    end)
    return found
end

-- EXPERIMENTAL: a worn container on a wolf renders as the saddlebag mesh
-- attached to the wolf spine (model attachment WTAGarou_Saddlebags). The
-- attached item is a hidden zero-weight stand-in; it is removed again the
-- moment the form is not a wolf or no container is worn.
-- setAttachedItem fires OnClothingUpdated, which re-enters this function
-- through Visual.refreshSaddlebag. Compare the desired full item type with
-- the actual attachment (including Black/Camo), under a re-entry guard.
-- Failed item creation must retry, not cache success and hide forever.
local saddlebagBusy = setmetatable({}, { __mode = "k" })
local function attachedVisual(player, loc)
    -- AttachedItems.getItem throws (and the engine logs a stack) for a
    -- location the "Human" group does not know. Register first; never query
    -- an unregistered location.
    if WTAGarou.EnsureAttachedLocation and not WTAGarou.EnsureAttachedLocation(loc) then
        return nil
    end
    local ok, res = pcall(function()
        local attached = player:getAttachedItems()
        return attached and attached.getItem and attached:getItem(loc) or nil
    end)
    return ok and res or nil
end
local function gearVariant(player)
    local remote=remoteStates[player]
    local md=player:getModData()
    return WTAGarou.WolfGearVariants[WTAGarou.WolfGearKey(
        remote and remote.wolfGearVariant or (md.WTAGarou and md.WTAGarou.wolfGearVariant))]
end
local function applySaddlebag(player, form)
    if not WTAGarou.EnableSaddlebagVisual then return end
    if not (player.setAttachedItem and player.getAttachedItems) then return end
    if saddlebagBusy[player] then return end
    local wolf = form == "Hispo" or form == "Lupus"
    local want = (wolf and wearsContainer(player)) == true
    local wantedItem=want and gearVariant(player).saddlebags or false
    local loc = WTAGarou.SaddlebagAttachment or "WTAGarou_Saddlebags"
    local have = attachedVisual(player, loc)
    if (not want and not have) or (want and have and have:getFullType()==wantedItem) then return end
    saddlebagBusy[player] = true
    local ok, err = pcall(function()
        if want then
            if WTAGarou.EnsureAttachedLocation then WTAGarou.EnsureAttachedLocation(loc) end
            local item = instanceItem(wantedItem)
            if not item then return end -- retry later without rebuilding the body
            player:setAttachedItem(loc, item)
        else
            player:setAttachedItem(loc, nil)
        end
        if player.resetModelNextFrame then player:resetModelNextFrame() end
    end)
    saddlebagBusy[player] = nil
    if not ok then print("[WTAGarou] saddlebag visual failed: " .. tostring(err)) end
end
Visual.applySaddlebag = applySaddlebag

-- 0.4.23: does the player have anything on the hotbar (other than our own
-- stand-ins) or in the secondary hand? That is what the harness follows.
local function hasHotbarItem(player)
    local found = false
    pcall(function()
        local attached = player:getAttachedItems()
        if attached and attached.size then
            local ours = { [WTAGarou.SaddlebagAttachment or "WTAGarou_Saddlebags"] = true,
                           [WTAGarou.HarnessAttachment or "WTAGarou_Harness"] = true }
            for i = 0, attached:size() - 1 do
                local a = attached:get(i)
                local loc = a and a.getLocation and a:getLocation() or nil
                local item = a and a.getItem and a:getItem() or nil
                if item and not ours[loc] then found = true; return end
            end
        end
        if not found and player.getSecondaryHandItem then
            local sec = player:getSecondaryHandItem()
            local prim = player.getPrimaryHandItem and player:getPrimaryHandItem() or nil
            if sec and sec ~= prim then found = true end
        end
    end)
    return found
end
Visual.hasHotbarItem = hasHotbarItem

-- The harness stand-in mirrors applySaddlebag: shown in a wolf form while a
-- hotbar / secondary-hand item is attached OR a container is worn (so the
-- saddlebags hang from more than a strap); removed only when there is
-- neither. Same re-entry guard shape (setAttachedItem fires
-- OnClothingUpdated).
local harnessBusy = setmetatable({}, { __mode = "k" })
local harnessLogs, harnessItemMissing = 0, false
local function applyHarness(player, form)
    if not WTAGarou.EnableHarnessVisual then return end
    if not (player.setAttachedItem and player.getAttachedItems) then return end
    if harnessBusy[player] then return end
    local wolf = form == "Hispo" or form == "Lupus"
    local want = (wolf and (hasHotbarItem(player) or wearsContainer(player))) == true
    local wantedItem=want and gearVariant(player).harness or false
    local loc = WTAGarou.HarnessAttachment or "WTAGarou_Harness"
    local have = attachedVisual(player, loc)
    if (not want and not have) or (want and have and have:getFullType()==wantedItem) then return end
    harnessBusy[player] = true
    local ok, err = pcall(function()
        if want then
            if WTAGarou.EnsureAttachedLocation then WTAGarou.EnsureAttachedLocation(loc) end
            local item = instanceItem(wantedItem)
            if not item then
                if not harnessItemMissing then
                    harnessItemMissing = true
                    print("[WTAGarou][Harness] carrier item unavailable: " .. tostring(wantedItem))
                end
                return
            end
            player:setAttachedItem(loc, item)
            if harnessLogs < 8 then
                harnessLogs = harnessLogs + 1
                print("[WTAGarou][Harness] carrier attached: " .. tostring(wantedItem))
            end
        else
            player:setAttachedItem(loc, nil)
        end
        if player.resetModelNextFrame then player:resetModelNextFrame() end
    end)
    harnessBusy[player] = nil
    if not ok then print("[WTAGarou] harness visual failed: " .. tostring(err)) end
end
Visual.applyHarness = applyHarness

local function javaReady()
    return WTAGarouJava and WTAGarouJava.setScale and WTAGarouJava.clear
end

local function applyScale(player, value, force)
    if not javaReady() then
        if not warnedJava then
            warnedJava = true
            print("[WTAGarou] Java scaling unavailable: approve WTAGarouVisuals.jar in ZombieBuddy and restart. Keeping normal size.")
        end
        return
    end
    if not force and scales[player] == value then return end
    if WTAGarouJava.setScale(player, value) then
        scales[player] = value
        print("[WTAGarou] Java scale requested=" .. tostring(value))
    end
end

-- Only restore our own override. Never replace another mod's current model.
local function restoreMesh(player)
    local original = originals[player]
    -- The default Java-scale path never set a mesh. Do not probe unavailable
    -- HumanVisual getters just to "restore" an override we never installed.
    if not original then return end
    local visual = player:getHumanVisual()
    if not visual then return end
    if not visual.getForceModelScript then return end
    local current = visual:getForceModelScript()
    local ours = current and tostring(current):find("WTAGarou_", 1, true)
    if not ours then
        originals[player] = nil
        return
    end
    visual:setForceModelScript(original and original.model or nil)
    visual:setSkinTextureName(original and original.skin or nil)
    player:resetModelNextFrame()
    originals[player] = nil
end

-- Retained only as an explicit model diagnostic, not a Java animation fix.
-- A successful setter is NOT evidence that a wolf rendered or animated.
function Visual.apply(player, model, skin, force)
    if not player then return false end
    if not WTAGarou.EnableModelSwap then model, skin = nil, nil end
    local key = tostring(model) .. "|" .. tostring(skin)
    if not force and applied[player] == key then return true end
    -- Cache a failed attempt too, to avoid throwing once per player update.
    applied[player] = key
    local ok, err = pcall(function()
        if not model or model == "" then
            restoreMesh(player)
            return
        end
        local visual = player:getHumanVisual()
        if not visual then return end
        if not visual.getForceModelScript or not visual.getSkinTextureName
                or not visual.setForceModelScript or not visual.setSkinTextureName then
            print("[WTAGarou] wolf mesh probe unavailable: required HumanVisual methods are not exposed. No override applied.")
            return
        end
        if not originals[player] then
            originals[player] = {
                model = visual:getForceModelScript(),
                skin = visual:getSkinTextureName(),
            }
        end
        visual:setForceModelScript(model)
        visual:setSkinTextureName(skin)
        player:resetModelNextFrame()
        print("[WTAGarou] EXPERIMENTAL mesh requested=" .. model .. "; rendering/animation not verified")
    end)
    if not ok then print("[WTAGarou] mesh request failed: " .. tostring(err)) end
    return ok
end

function Visual.clear(player)
    if not player then return end
    WTAGarou.CrinosAttack.clear(player)
    if javaReady() then WTAGarouJava.clear(player) end
    scales[player] = nil
    stabilities[player] = nil
    stealthForms[player] = nil
    traitsApplied[player] = nil
    wolfStates[player] = nil
    crinosStates[player] = nil
    preloadStates[player] = nil
    -- Java clear() also drops these; forget the cache so the next refresh re-pushes.
    grappleForward[player] = nil
    shoulderPickup[player] = nil
    meleeRange[player] = nil
    applySaddlebag(player, "Homid")
    applyHarness(player, "Homid")
    Visual.apply(player, nil, nil, false)
end

function Visual.refresh(player, force)
    if not player then return end
    local remote = remoteStates[player]
    local observer = isClient and isClient() and player.isLocalPlayer and not player:isLocalPlayer()
    local garou = WTAGarou.HasGarouTrait(player)
    if observer then garou = remote and remote.garou == true end
    if player:isDead() or not garou or (remote and remote.alive == false) then
        Visual.clear(player)
        return
    end
    local md = player:getModData()
    local form = remote and remote.form or (md.WTAGarou and md.WTAGarou.form or "Homid")
    WTAGarou.CrinosAttack.refresh(player, form)
    local fd = WTAGarou.GetForm(form)
    if WTAGarouJava and WTAGarouJava.setWolfCoat then
        local coat=remote and remote.wolfCoat or (md.WTAGarou and md.WTAGarou.wolfCoat) or "default"
        local entry=(WTAGarou.WolfCoats or {})[coat]
        if WTAGarouJava.setWolfTexture and entry then
            WTAGarouJava.setWolfTexture(player,entry.path)
        else WTAGarouJava.setWolfCoat(player,coat) end
    end
    if WTAGarou.EnableJavaScale then
        applyScale(player, fd.modelScale or 1.0, force)
    elseif javaReady() then
        if WTAGarouJava.clearScale then WTAGarouJava.clearScale(player)
        else WTAGarouJava.clear(player) end
        scales[player] = nil
    end
    -- Mass-based knockdown/trip resistance lives in the Java stability
    -- patches; the local client owns its own fall decisions in the engine.
    if WTAGarouJava and WTAGarouJava.setStability then
        local chance = (WTAGarou.Stability or {})[form] or 0
        if stabilities[player] ~= chance then
            stabilities[player] = chance
            pcall(function() WTAGarouJava.setStability(player, chance) end)
            print("[WTAGarou] stability requested form=" .. tostring(form) .. " chance=" .. tostring(chance))
        end
    end
    -- 0.4.68: poise (melee flinch shrugged off) and the tall-form doorway
    -- rules live in Java too; both are per-form flags on the local client.
    if WTAGarouJava and WTAGarouJava.setPoise then
        local chance = (WTAGarou.Poise or {})[form] or 0
        if poises[player] ~= chance or force then
            local ok = pcall(function() WTAGarouJava.setPoise(player, chance) end)
            if ok then poises[player] = chance end
        end
    end
    -- 0.4.75: the Garou's vanilla voice drops with the form (each client
    -- pitches every copy it can hear; the default is learned in a base form).
    if WTAGarou.ApplyVoicePitch then
        local okp, pitch = pcall(WTAGarou.ApplyVoicePitch, player, form)
        if okp and pitch and voicePitches[player] ~= pitch then
            voicePitches[player] = pitch
            print("[WTAGarou] voice pitch form=" .. tostring(form) .. " -> " .. tostring(pitch))
        end
    end
    -- 0.4.72: per-form health pool (damage intake on the local client's own
    -- BodyDamage; a remote player's copy here is not authoritative anyway).
    if WTAGarouJava and WTAGarouJava.setDamageIntake then
        local intake = WTAGarou.DamageIntakeFor and WTAGarou.DamageIntakeFor(form) or 1.0
        if intakes[player] ~= intake or force then
            local ok = pcall(function() WTAGarouJava.setDamageIntake(player, intake) end)
            if ok then
                intakes[player] = intake
                print("[WTAGarou] damage intake requested form=" .. tostring(form) .. " intake=" .. tostring(intake)
                    .. " (pool " .. tostring(math.floor(100 / intake + 0.5)) .. ")")
            end
        end
    end
    if WTAGarouJava and WTAGarouJava.setTallForm then
        local tall = ((WTAGarou.Doorway or {}).TALL_FORMS or {})[form] == true
        if tallFlags[player] ~= tall or force then
            local ok, err = pcall(function() WTAGarouJava.setTallForm(player, tall) end)
            if ok then tallFlags[player] = tall
            else print("[WTAGarou] tall-form request failed: " .. tostring(err)) end
        end
    end
    -- 0.4.69: crowd charge (sprinting knocks down the first zombies in the way).
    if WTAGarouJava and WTAGarouJava.setCrowdCharge then
        local limit, window = WTAGarou.CrowdChargeFor(form)
        local key = limit .. ":" .. window
        if crowdRules[player] ~= key or force then
            local ok, err = pcall(function() WTAGarouJava.setCrowdCharge(player, limit, window) end)
            if ok then crowdRules[player] = key
            else print("[WTAGarou] crowd-charge request failed: " .. tostring(err)) end
        end
    end
    applyStealth(player, form)
    applyTraits(player, form, force)
    if WTAGarouJava and WTAGarouJava.setFurInsulation then
        local floor = WTAGarou.FurInsulation(form)
        pcall(function() WTAGarouJava.setFurInsulation(player, floor) end)
    end
    -- 0.4.39: Crinos/Hispo are flagged in the Java BulkFormRuntime so
    -- BaseVehicle.isEnterBlocked and the window climb know the form.
    if WTAGarouJava and WTAGarouJava.setBulkForm then
        local bulk = WTAGarou.IsBulkForm and WTAGarou.IsBulkForm(form) == true or false
        if bulkFlags[player] ~= bulk or force then
            local ok, err = pcall(function() WTAGarouJava.setBulkForm(player, bulk) end)
            if ok then bulkFlags[player] = bulk
            else print("[WTAGarou] bulk-form request failed: " .. tostring(err)) end
        end
    end
    -- 0.4.40: wolf forms carry a dragged corpse further forward (Java
    -- GrappleOffsetPatch adds this while the character is dragging).
    if WTAGarouJava and WTAGarouJava.setGrappleForward and WTAGarou.CorpseCarry then
        local metres = WTAGarou.CorpseCarry.grappleForward(form)
        if grappleForward[player] ~= metres or force then
            local ok, err = pcall(function() WTAGarouJava.setGrappleForward(player, metres) end)
            if ok then grappleForward[player] = metres
            else print("[WTAGarou] grapple-forward request failed: " .. tostring(err)) end
        end
    end
    -- 0.4.44: shoulders grab from the ground is held at the carry distance.
    if WTAGarouJava and WTAGarouJava.setShoulderPickupDistance and WTAGarou.CorpseCarry
            and WTAGarou.CorpseCarry.shoulderPickupDistance then
        local metres = WTAGarou.CorpseCarry.shoulderPickupDistance(form)
        if shoulderPickup[player] ~= metres or force then
            local ok, err = pcall(function() WTAGarouJava.setShoulderPickupDistance(player, metres) end)
            if ok then shoulderPickup[player] = metres
            else print("[WTAGarou] shoulder-pickup request failed: " .. tostring(err)) end
        end
    end
    -- 0.4.42: Hispo/Lupus melee reach (Java MeleeRangePatch).
    if WTAGarouJava and WTAGarouJava.setMeleeRange and WTAGarou.WolfMelee then
        local mult = WTAGarou.WolfMelee.rangeFor(form)
        if meleeRange[player] ~= mult or force then
            local ok, err = pcall(function() WTAGarouJava.setMeleeRange(player, mult) end)
            if ok then meleeRange[player] = mult
            else print("[WTAGarou] melee-range request failed: " .. tostring(err)) end
        end
    end
    applySaddlebag(player, form)
    applyHarness(player, form)
    local vehicle = player.getVehicle and player:getVehicle()
    refreshWolf(player, WTAGarou.EnableDirectWolf == true
        and not vehicle and (form == "Hispo" or form == "Lupus"), force)
    local coat = remote and remote.wolfCoat or (md.WTAGarou and md.WTAGarou.wolfCoat) or "default"
    -- 0.4.59: warm the shift assets while still in Homid so the first channel
    -- does not end on an unclothed human body waiting for the loader.
    preload(player, coat)
    refreshCrinos(player,form,coat,force)
    local model, skin
    if WTAGarou.ModelSwapAllowed(form) then
        model = fd.modelScript
        if fd.modelScriptFemale and player:isFemale() then model = fd.modelScriptFemale end
        skin = fd.skinTextureName
    end
    Visual.apply(player, model, skin, force)
end

-- Re-evaluate the saddlebag when worn gear changes (called from the wolf
-- voice module's clothing hook and after the shift strip).
-- 0.4.22: forget the last wolf request so the next refresh re-pushes the
-- Definitions tunables and re-asks Java for the wolf (Reload defs).
function Visual.forgetWolf(player)
    if player then wolfStates[player] = nil end
end

function Visual.refreshSaddlebag(player)
    if not player then return end
    local md = player:getModData()
    local remote = remoteStates[player]
    local form = remote and remote.form or (md.WTAGarou and md.WTAGarou.form or "Homid")
    -- Compare actual attachments; both helpers guard OnClothingUpdated re-entry.
    applySaddlebag(player, form)
    applyHarness(player, form)
    -- Actual item aliases (e.g. shovel on Back) change on equip/attach,
    -- not just on form changes or Reload defs.
    if form=="Hispo" or form=="Lupus" then Visual.pushWolfSlots(player) end
end

function Visual.setRemoteState(player, state, force)
    if not player or not player.isLocalPlayer or player:isLocalPlayer() then return end
    remoteStates[player] = state
    if not state then Visual.clear(player)
    else Visual.refresh(player, force) end
end

function WTAGarouVisualStatus()
    if javaReady() then
        print(WTAGarouJava.status())
    else
        print("[WTAGarou] Java API missing; scaling is inactive.")
    end
end

-- Opt-in runtime probe, deliberately not persisted in the save.
function WTAGarouTestWolfMesh(enabled)
    -- Legacy diagnostic is mutually exclusive with the direct-body adapter.
    WTAGarou.EnableDirectWolf = false
    WTAGarou.EnableModelSwap = enabled == true
    print("[WTAGarou] experimental wolf mesh=" .. tostring(WTAGarou.EnableModelSwap))
    local player = getPlayer()
    if player then Visual.refresh(player, true) end
end

function WTAGarouDirectWolf(enabled)
    WTAGarou.EnableDirectWolf = enabled == true
    WTAGarou.EnableModelSwap = false
    local player = getPlayer()
    if player then Visual.refresh(player, true) end
    WTAGarouVisualStatus()
end

Events.OnCreatePlayer.Add(function(_, player) Visual.refresh(player, true) end)
Events.OnPlayerUpdate.Add(function(player) Visual.refresh(player, false) end)
Events.OnPlayerDeath.Add(function(player) Visual.clear(player) end)
