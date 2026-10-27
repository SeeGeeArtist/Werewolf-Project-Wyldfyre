require "WTAGarouWolfCoats"
require "WTAGarouWolfGear"
require "WTAGarouNet"
require "WTAGarouState"
local function handleWolfCoat(module, command, player, args)
    if module ~= "WTAGarou" or (command ~= "SelectWolfCoat" and command ~= "RequestWolfCoat"
            and command ~= "SelectWolfGear" and command ~= "SelectCrinosTail") then return end
    if not player or player:isDead() or not WTAGarou.HasGarouTrait(player) then return end
    if command == "SelectWolfCoat" and (type(args) ~= "table" or not WTAGarou.ValidWolfCoat(args.coat)) then return end
    if command=="SelectWolfCoat" and args.trueForm~=nil and not WTAGarou.ValidTrueForm(args.trueForm) then return end
    if command=="SelectWolfCoat" and args.auspice~=nil and not WTAGarou.ValidAuspice(args.auspice) then return end
    if command=="SelectWolfGear" and (type(args)~="table" or not WTAGarou.ValidWolfGear(args.variant)) then return end
    if command=="SelectCrinosTail" and (type(args)~="table" or type(args.tail)~="boolean") then return end
    -- The sender may choose only their own allowlisted cosmetic, never a
    -- model path, another player's id, form, Rage, or other gameplay state.
    local data = WTAGarou.GetData(player)
    if command=="SelectWolfGear" then
        data.wolfGearVariant=args.variant
    end
    -- 0.4.67: tail on/off never locks (like gear); nil = off keeps old saves tail-less.
    if command=="SelectCrinosTail" then
        data.crinosTail=args.tail==true or nil
    end
    if command == "SelectWolfCoat" then
        if data.pendingForm then return end
        -- 0.4.39: true form and coat lock once confirmed. The client only
        -- sends SelectWolfCoat after its "Are you sure?" dialog, so the first
        -- accepted choice is the confirmation; later ones are refused (gear
        -- keeps its own SelectWolfGear command and never locks).
        -- 0.4.45: the auspice (Baseline Rage) locks with them. A save locked
        -- before 0.4.45 may still confirm its auspice once.
        if WTAGarou.IdentityLocked(data) and not WTAGarou.AuspiceLocked(data) and WTAGarou.ValidAuspice(args.auspice) then
            data.auspice=args.auspice
            data.auspiceLocked=true
            print("[WTAGarou][WolfCoat] baseline Rage confirmed: "..tostring(args.auspice)
                .." -> "..tostring(WTAGarou.BaselineRage(data)))
            WTAGarou.Net.ToClient(player, "WolfCoatSelected", {
                coat=WTAGarou.ValidWolfCoat(data.wolfCoat) and data.wolfCoat or "",
                playerNum=player:getPlayerNum(), onlineID=player:getOnlineID(),
                trueForm=data.trueForm or "", form=data.form,
                wolfGearVariant=WTAGarou.WolfGearKey(data.wolfGearVariant),
                crinosTail=WTAGarou.CrinosTailOn(data.crinosTail),
                identityLocked=true, auspice=data.auspice, auspiceLocked=true,
            })
            return
        end
        if WTAGarou.IdentityLocked(data) then
            print("[WTAGarou][WolfCoat] identity already confirmed; coat/true form change refused")
            WTAGarou.Net.ToClient(player, "WolfCoatSelected", {
                coat=WTAGarou.ValidWolfCoat(data.wolfCoat) and data.wolfCoat or "",
                playerNum=player:getPlayerNum(), onlineID=player:getOnlineID(),
                trueForm=data.trueForm or "", form=data.form,
                wolfGearVariant=WTAGarou.WolfGearKey(data.wolfGearVariant),
                crinosTail=WTAGarou.CrinosTailOn(data.crinosTail),
                identityLocked=true, auspice=data.auspice, auspiceLocked=WTAGarou.AuspiceLocked(data),
            })
            return
        end
        data.wolfCoat = args.coat
        -- Native corpse modData copy preserves these allowlisted plain values.
        data.isGarou=true
        data.wolfCoatTexture=WTAGarou.WolfCoats[args.coat].path
        if args.trueForm~=nil then
            local firstChoice=not WTAGarou.ValidTrueForm(data.trueForm)
            data.trueForm=args.trueForm
            -- Only initial setup grants the starting form. Subsequent edits
            -- must not become a free-shift button.
            if firstChoice and (data.form==nil or data.form=="Homid") then
                data.form=WTAGarou.BaseForm(data)
                if WTAGarou.ApplyFormBuffs then WTAGarou.ApplyFormBuffs(player) end
            end
        end
        if WTAGarou.ValidTrueForm(data.trueForm) then data.identityLocked=true end
        if WTAGarou.ValidAuspice(args.auspice) then
            data.auspice=args.auspice
            data.auspiceLocked=true
            print("[WTAGarou][WolfCoat] baseline Rage confirmed: "..tostring(args.auspice)
                .." -> "..tostring(WTAGarou.BaselineRage(data)))
        end
    end
    WTAGarou.Net.ToClient(player, "WolfCoatSelected", {
        coat=WTAGarou.ValidWolfCoat(data.wolfCoat) and data.wolfCoat or "",
        playerNum=player:getPlayerNum(), onlineID=player:getOnlineID(),
        trueForm=data.trueForm or "", form=data.form,
        wolfGearVariant=WTAGarou.WolfGearKey(data.wolfGearVariant),
        crinosTail=WTAGarou.CrinosTailOn(data.crinosTail),
        identityLocked=WTAGarou.IdentityLocked(data),
        auspice=data.auspice, auspiceLocked=WTAGarou.AuspiceLocked(data),
    })
end
Events.OnClientCommand.Add(handleWolfCoat)
WTAGarou.Net.RegisterServerHandler(handleWolfCoat)
