require "ISUI/ISCollapsableWindow"
require "ISUI/ISButton"
require "WTAGarouWolfCoats"
require "WTAGarouWolfGear"
require "WTAGarouNet"
require "WTAGarouLocalPlayers"
require "WTAGarouState"
WTAGarou.WolfCoat = WTAGarou.WolfCoat or {}
local Coat = WTAGarou.WolfCoat
local prompted = setmetatable({}, {__mode="k"})
local windows = setmetatable({}, {__mode="k"})
local ready = setmetatable({}, {__mode="k"})
local requested = setmetatable({}, {__mode="k"})
WTAGarouCoatWindow = ISCollapsableWindow:derive("WTAGarouCoatWindow")

-- 0.4.39 layout (340 wide): true-form row (3 buttons), staged coat grid,
-- 0.4.45: a "Baseline Rage" row (one button per auspice: 30 40 50 60 70),
-- a Confirm button that opens "Are you sure?", then the Wolf Gear row.
-- True form, coat and baseline lock after one confirmation; gear changes
-- any time. Saves locked before 0.4.45 may still confirm their baseline.
local TRUE_FORMS={"Homid","Lupus","Glabro"}
local AUSPICE_ROW_HEIGHT=62
local TAIL_ROW_HEIGHT=62 -- 0.4.67: Crinos tail row under Wolf Gear
-- "[Moon] Werewolf. As a [Auspice], rage value gravitates to [n] when
-- you're healthy and happy." Highlights via WTAGarou.Rich (tags stand alone
-- between spaces + <SPACE>, so the gaps survive Build 42's rich text).
function Coat.auspiceTooltip(auspice)
    local R=WTAGarou.Rich
    return R.lead(auspice.moon,"lore").."Werewolf. As a"..R.kw(auspice.key..",","lore")
        .."rage value gravitates to"..R.kw(tostring(auspice.baseline),"rage").."when you're healthy and happy."
end
local TRUE_FORM_TIPS={
    Homid="Human-born (Homid). Starts as, and returns to, Human at 0 Rage.",
    Lupus="Wolf-born (Lupus). Starts as, and returns to, Wolf at 0 Rage.",
    Glabro="Metis breed: born of two Garou, never fully at home in either skin. "
        .."Starts as, and returns to, Near-Human at 0 Rage. "
        .."Berzerker form needs no Rage floor (cost 10) and burns half as fast, "
        .."but will not let you out above 55 Rage.",
}
-- 0.4.40: the selected option is shown by colour and a heavier border, not
-- by a text suffix (the true-form row was too crowded for it).
Coat.SELECTED_BORDER={r=1.0,g=0.82,b=0.30,a=1.0}
Coat.SELECTED_BACKGROUND={r=0.42,g=0.33,b=0.10,a=1.0}
Coat.DEFAULT_BORDER={r=0.7,g=0.7,b=0.7,a=0.4}
Coat.DEFAULT_BACKGROUND={r=0.0,g=0.0,b=0.0,a=0.25}
local function markSelected(button,selected)
    if not button then return end
    button.selected=selected and true or false
    if button.baseLabel then button:setTitle(button.baseLabel) end
    button.borderColor=selected and Coat.SELECTED_BORDER or Coat.DEFAULT_BORDER
    button.backgroundColor=selected and Coat.SELECTED_BACKGROUND or Coat.DEFAULT_BACKGROUND
end
Coat.markSelected=markSelected
function WTAGarouCoatWindow:new(player)
    local keys=WTAGarou.WolfCoatKeys()
    local rows=math.ceil(#keys/2)
    local height=282+rows*38+AUSPICE_ROW_HEIGHT+TAIL_ROW_HEIGHT
    local x,y=getPlayerScreenLeft(player:getPlayerNum())+40,getPlayerScreenTop(player:getPlayerNum())+100
    local hud=WTAGarou.HUDFor(player)
    local left=getPlayerScreenLeft(player:getPlayerNum())
    if hud then x=hud:getX(); y=hud:getY()+hud:getHeight()+12 end
    x=math.max(left+40,x)
    if getPlayerScreenWidth and getPlayerScreenHeight then
        local left,top=getPlayerScreenLeft(player:getPlayerNum()),getPlayerScreenTop(player:getPlayerNum())
        x=math.max(left+40,math.min(x,left+getPlayerScreenWidth(player:getPlayerNum())-340-16))
        y=math.max(top,math.min(y,top+getPlayerScreenHeight(player:getPlayerNum())-height))
    end
    local o=ISCollapsableWindow.new(self,x,y,340,height)
    local data=WTAGarou.GetData(player)
    o.coatKeys=keys
    o.auspiceLabelY=131+rows*38+4
    o.auspiceY=o.auspiceLabelY+22
    o.confirmY=o.auspiceY+30+10
    o.gearY=o.confirmY+30+8+24
    o.wolfGear=WTAGarou.WolfGearKey(data.wolfGearVariant)
    o.tailY=o.gearY+30+8+24
    o.crinosTail=WTAGarou.CrinosTailOn(data.crinosTail)
    o.footerY=height-33
    o.player=player
    o.trueForm=WTAGarou.BaseForm(data)
    o.coat=WTAGarou.ValidWolfCoat(data.wolfCoat) and data.wolfCoat or nil
    o.locked=WTAGarou.IdentityLocked(data)
    o.auspice=WTAGarou.ValidAuspice(data.auspice) and data.auspice or nil
    o.auspiceLocked=WTAGarou.AuspiceLocked(data)
    o.resizable=false
    o:setTitle(Coat.TITLE)
    return o
end
function WTAGarouCoatWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self.trueButtons={}
    for i,form in ipairs(TRUE_FORMS) do
        local label=WTAGarou.TrueFormLabel(form)
        local button=ISButton:new(16+(i-1)*104,54,98,30,label,self,WTAGarouCoatWindow.chooseTrueForm)
        button.trueForm=form; button.baseLabel=label
        button:initialise(); self:addChild(button)
        markSelected(button,self.trueForm==form)
        button:setTooltip(TRUE_FORM_TIPS[form])
        self.trueButtons[#self.trueButtons+1]=button
    end
    self.coatButtons={}
    for i,key in ipairs(self.coatKeys) do
        local button=ISButton:new(16+((i-1)%2)*156,131+math.floor((i-1)/2)*38,150,30,
            WTAGarou.WolfCoats[key].label,self,WTAGarouCoatWindow.choose)
        button.coat=key; button.baseLabel=WTAGarou.WolfCoats[key].label
        button:initialise()
        self:addChild(button)
        markSelected(button,self.coat==key)
        if not getTexture(WTAGarou.WolfCoats[key].path) then
            button.enable=false
            button:setTooltip("Texture missing. Pull the texture file and restart.")
        end
        self.coatButtons[#self.coatButtons+1]=button
    end
    self.auspiceButtons={}
    for i,auspice in ipairs(WTAGarou.Auspices) do
        local label=tostring(auspice.baseline)
        local button=ISButton:new(16+(i-1)*63,self.auspiceY,56,30,label,self,WTAGarouCoatWindow.chooseAuspice)
        button.auspice=auspice.key; button.baseLabel=label
        button:initialise(); self:addChild(button)
        markSelected(button,self.auspice==auspice.key)
        button:setTooltip(Coat.auspiceTooltip(auspice))
        self.auspiceButtons[#self.auspiceButtons+1]=button
    end
    self.confirmButton=ISButton:new(16,self.confirmY,308,30,"Confirm true form, coat and baseline Rage",self,WTAGarouCoatWindow.confirm)
    self.confirmButton:initialise(); self:addChild(self.confirmButton)
    self.confirmButton:setTooltip("Locks your true form, coat and baseline Rage for this character. Wolf gear stays changeable.")
    self.gearButtons={}
    for i,key in ipairs({"Black","Camo"}) do
        local button=ISButton:new(16+(i-1)*156,self.gearY,150,30,key,self,WTAGarouCoatWindow.chooseGear)
        button.gear=key; button.baseLabel=key
        button:initialise(); self:addChild(button)
        markSelected(button,self.wolfGear==key)
        self.gearButtons[#self.gearButtons+1]=button
    end
    -- 0.4.67: Crinos tail on/off. Default is the tail-less Crinos.
    self.tailButtons={}
    for i,opt in ipairs({{tail=false,label="No tail"},{tail=true,label="Tail"}}) do
        local button=ISButton:new(16+(i-1)*156,self.tailY,150,30,opt.label,self,WTAGarouCoatWindow.chooseTail)
        button.tail=opt.tail; button.baseLabel=opt.label
        button:initialise(); self:addChild(button)
        markSelected(button,self.crinosTail==opt.tail)
        button:setTooltip(opt.tail and "Crinos grows a tail." or "Tail-less Crinos.")
        self.tailButtons[#self.tailButtons+1]=button
    end
    self:refreshLock()
end
function WTAGarouCoatWindow:refreshLock()
    local locked=self.locked==true
    for _,b in ipairs(self.trueButtons or {}) do
        b.enable=not locked
        if locked then b:setTooltip("Locked in. Your true form was confirmed.") end
    end
    for _,b in ipairs(self.coatButtons or {}) do
        if locked then b.enable=false; b:setTooltip("Locked in. Your coat was confirmed.") end
    end
    local auspiceLocked=self.auspiceLocked==true
    for _,b in ipairs(self.auspiceButtons or {}) do
        b.enable=not auspiceLocked
        if auspiceLocked then b:setTooltip("Locked in. Your baseline Rage was confirmed.") end
    end
    if self.confirmButton then
        if locked and auspiceLocked then
            self.confirmButton.enable=false
            self.confirmButton:setTitle("Confirmed")
        elseif locked then
            -- A save confirmed before 0.4.45: only the baseline is still open.
            self.confirmButton.enable=self.auspice~=nil
            self.confirmButton:setTitle("Confirm baseline Rage")
        else
            self.confirmButton.enable=self.coat~=nil and self.auspice~=nil
        end
    end
end
function WTAGarouCoatWindow:prerender()
    ISCollapsableWindow.prerender(self)
    if self.locked then
        self:drawText("True form and coat are locked in.",16,31,0.8,0.8,0.8,1,UIFont.Small)
        self:drawText("Coat (locked)",16,101,0.8,0.8,0.8,1,UIFont.Small)
    else
        self:drawText("True form: starting / zero-Rage form.",16,31,1,1,1,1,UIFont.Small)
        self:drawText("Coat: pick one, then Confirm below.",16,101,1,1,1,1,UIFont.Small)
    end
    if self.auspiceLocked then
        self:drawText("Baseline Rage (locked)",16,self.auspiceLabelY,0.8,0.8,0.8,1,UIFont.Small)
    else
        self:drawText("Baseline Rage (hover a number for details)",16,self.auspiceLabelY,1,1,1,1,UIFont.Small)
    end
    self:drawText("Wolf Gear (saves immediately, change any time)",16,self.gearY-23,1,1,1,1,UIFont.Small)
    self:drawText("Crinos Tail (saves immediately, change any time)",16,self.tailY-23,1,1,1,1,UIFont.Small)
    self:drawText(Coat.footerText(self.locked),16,self.footerY,0.8,0.8,0.8,1,UIFont.Small)
    -- Heavier (2 px) outline around whichever option is selected in each row.
    if self.drawRectBorder then
        local c=Coat.SELECTED_BORDER
        for _,list in ipairs({self.trueButtons or {},self.coatButtons or {},self.auspiceButtons or {},self.gearButtons or {}}) do
            for _,b in ipairs(list) do
                if b.selected and b.getX then
                    local bx,by,bw,bh=b:getX(),b:getY(),b:getWidth(),b:getHeight()
                    self:drawRectBorder(bx-1,by-1,bw+2,bh+2,c.a,c.r,c.g,c.b)
                    self:drawRectBorder(bx-2,by-2,bw+4,bh+4,c.a*0.6,c.r,c.g,c.b)
                end
            end
        end
    end
end
-- 0.4.42: one name for the window and the footer tip. 0.4.45: "Werewolf
-- Startup"; reopened from the Rage panel's Startup button (the world
-- context entry is gone).
Coat.TITLE = "Werewolf Startup"
Coat.REOPEN_BUTTON = "Startup"
function Coat.footerText(locked)
    return "Reopen later: Rage panel > " .. Coat.REOPEN_BUTTON .. "."
end
function WTAGarouCoatWindow:chooseGear(button)
    local player=self.player
    if player:isDead() or not WTAGarou.HasGarouTrait(player) then self:close(); return end
    WTAGarou.Net.ToServer(player,"SelectWolfGear",{variant=button.gear})
end
function WTAGarouCoatWindow:updateGear(key)
    self.wolfGear=WTAGarou.WolfGearKey(key)
    for _,button in ipairs(self.gearButtons or {}) do
        markSelected(button,button.gear==self.wolfGear)
    end
end
function WTAGarouCoatWindow:chooseTail(button)
    local player=self.player
    if player:isDead() or not WTAGarou.HasGarouTrait(player) then self:close(); return end
    WTAGarou.Net.ToServer(player,"SelectCrinosTail",{tail=button.tail==true})
end
function WTAGarouCoatWindow:updateTail(on)
    self.crinosTail=WTAGarou.CrinosTailOn(on)
    for _,button in ipairs(self.tailButtons or {}) do
        markSelected(button,button.tail==self.crinosTail)
    end
end
function WTAGarouCoatWindow:chooseAuspice(button)
    if self.auspiceLocked then return end
    self.auspice=button.auspice
    for _,b in ipairs(self.auspiceButtons or {}) do markSelected(b,b.auspice==self.auspice) end
    self:refreshLock()
end
function WTAGarouCoatWindow:chooseTrueForm(button)
    if self.locked then return end
    self.trueForm=button.trueForm
    for _,b in ipairs(self.trueButtons) do markSelected(b,b.trueForm==self.trueForm) end
end
-- Coat clicks only stage the choice; nothing is sent until Confirm.
function WTAGarouCoatWindow:choose(button)
    if self.locked then return end
    self.coat=button.coat
    for _,b in ipairs(self.coatButtons or {}) do markSelected(b,b.coat==self.coat) end
    self:refreshLock()
end
function WTAGarouCoatWindow:confirm()
    local player=self.player
    if player:isDead() or not WTAGarou.HasGarouTrait(player) then self:close(); return end
    if self.auspiceLocked or not WTAGarou.ValidAuspice(self.auspice) then return end
    if not self.locked and not WTAGarou.ValidWolfCoat(self.coat) then return end
    local a=WTAGarou.AuspiceByKey(self.auspice)
    local text
    if self.locked then
        text=string.format("Are you sure?\n\nBaseline Rage: %d (%s)\n\nThis locks for this character.",a.baseline,a.moon)
    else
        text=string.format("Are you sure?\n\nTrue form: %s\nCoat: %s\nBaseline Rage: %d (%s)\n\nThese lock for this character. Wolf gear can still be changed.",
            WTAGarou.TrueFormLabel(self.trueForm),WTAGarou.WolfCoats[self.coat].label,a.baseline,a.moon)
    end
    if ISModalDialog then
        local w,h=340,190
        local modal=ISModalDialog:new(self.x+(self.width-w)/2,self.y+(self.height-h)/2,w,h,text,true,self,WTAGarouCoatWindow.onConfirmDialog)
        modal:initialise(); modal:addToUIManager()
        if modal.setAlwaysOnTop then modal:setAlwaysOnTop(true) end
        self.modal=modal
    else
        self:onConfirmDialog({internal="YES"})
    end
end
function WTAGarouCoatWindow:onConfirmDialog(button)
    self.modal=nil
    if not button or button.internal~="YES" then return end
    local player=self.player
    if player:isDead() or not WTAGarou.HasGarouTrait(player) then self:close(); return end
    if self.auspiceLocked or not WTAGarou.ValidAuspice(self.auspice) then return end
    local d=WTAGarou.GetData(player)
    if self.locked then
        -- Pre-0.4.45 save: the coat/true form are already locked, send them back unchanged.
        WTAGarou.Net.ToServer(player,"SelectWolfCoat",{coat=d.wolfCoat,trueForm=d.trueForm,auspice=self.auspice,confirm=true})
    else
        if not WTAGarou.ValidWolfCoat(self.coat) then return end
        WTAGarou.Net.ToServer(player,"SelectWolfCoat",{coat=self.coat,trueForm=self.trueForm,auspice=self.auspice,confirm=true})
    end
    -- Single player answers in-process; multiplayer locks when the reply lands.
    if WTAGarou.IdentityLocked(d) then
        self:applyLock({identityLocked=true,coat=d.wolfCoat,trueForm=d.trueForm,
            auspice=d.auspice,auspiceLocked=WTAGarou.AuspiceLocked(d)})
    end
    -- Keep the picker open so the gear row below remains reachable.
end
function WTAGarouCoatWindow:applyLock(args)
    if args.identityLocked then
        self.locked=true
        if WTAGarou.ValidWolfCoat(args.coat) then self.coat=args.coat end
        if WTAGarou.ValidTrueForm(args.trueForm) then self.trueForm=args.trueForm end
        for _,b in ipairs(self.trueButtons or {}) do markSelected(b,b.trueForm==self.trueForm) end
        for _,b in ipairs(self.coatButtons or {}) do markSelected(b,b.coat==self.coat) end
        self:setTitle(Coat.TITLE)
    end
    if args.auspiceLocked then
        self.auspiceLocked=true
        if WTAGarou.ValidAuspice(args.auspice) then self.auspice=args.auspice end
        for _,b in ipairs(self.auspiceButtons or {}) do markSelected(b,b.auspice==self.auspice) end
    end
    self:refreshLock()
end
function Coat.open(player)
    if not player or player:isDead() or not WTAGarou.HasGarouTrait(player) then return end
    if windows[player] then windows[player]:close() end
    local window=WTAGarouCoatWindow:new(player)
    window:initialise(); window:addToUIManager()
    windows[player]=window
end
function Coat.receive(args, recipient)
    if type(args)~="table" or (args.coat~="" and not WTAGarou.ValidWolfCoat(args.coat)) then return end
    if args.wolfGearVariant~=nil and not WTAGarou.ValidWolfGear(args.wolfGearVariant) then return end
    if args.crinosTail~=nil and type(args.crinosTail)~="boolean" then return end
    local player=recipient
    if not player and WTAGarou.Net.IsSinglePlayer() then
        player=getSpecificPlayer(tonumber(args.playerNum) or 0)
    elseif not player and type(args.onlineID)=="number" and args.onlineID>=0 then
        -- Server playerNum is NOT the receiving client's split-screen index.
        for i=0,(getNumActivePlayers and getNumActivePlayers() or 4)-1 do
            local p=getSpecificPlayer(i)
            if p and p:getOnlineID()==args.onlineID then player=p; break end
        end
    end
    if not player then return end
    ready[player]=true
    local data=WTAGarou.GetData(player)
    data.wolfGearVariant=WTAGarou.WolfGearKey(args.wolfGearVariant)
    if args.crinosTail~=nil then data.crinosTail=args.crinosTail==true or nil end
    data.wolfCoat=args.coat~="" and args.coat or nil
    if WTAGarou.ValidTrueForm(args.trueForm) then data.trueForm=args.trueForm end
    data.identityLocked=args.identityLocked==true or nil
    if args.auspiceLocked~=nil then
        data.auspiceLocked=args.auspiceLocked==true or nil
        data.auspice=WTAGarou.ValidAuspice(args.auspice) and args.auspice or nil
    end
    if windows[player] then
        windows[player]:updateGear(data.wolfGearVariant)
        windows[player]:updateTail(data.crinosTail)
        windows[player]:applyLock(args)
    end
    if WTAGarou.ValidWolfCoat(args.coat) then
        data.isGarou=true
        data.wolfCoatTexture=WTAGarou.WolfCoats[args.coat].path
    end
    if WTAGarou.Forms and WTAGarou.Forms[args.form] then data.form=args.form end
    if WTAGarou.Visual then WTAGarou.Visual.refresh(player,true) end
end
Events.OnPlayerUpdate.Add(function(player)
    if player.isLocalPlayer and not player:isLocalPlayer() then return end
    if prompted[player] or player:isDead() or not WTAGarou.HasGarouTrait(player) then return end
    if not WTAGarou.Net.IsSinglePlayer() and not ready[player] then
        local now=getTimestamp()
        if not requested[player] or now-requested[player]>=5 then
            requested[player]=now
            WTAGarou.Net.ToServer(player,"RequestWolfCoat",{})
        end
        return
    end
    prompted[player]=true
    local data=WTAGarou.GetData(player)
    if not WTAGarou.ValidWolfCoat(data.wolfCoat) or not WTAGarou.ValidTrueForm(data.trueForm)
            or not WTAGarou.AuspiceLocked(data) then Coat.open(player) end
end)
-- 0.4.45: no world context entry any more; the Rage panel's Startup button
-- (WTAGarouHUD) calls Coat.open / Coat.toggle.
function Coat.toggle(player)
    player=player or getPlayer()
    if windows[player] then windows[player]:close(); return end
    Coat.open(player)
end
function WTAGarouCoatWindow:close()
    if windows[self.player]==self then windows[self.player]=nil end
    ISCollapsableWindow.close(self)
end
Events.OnPlayerDeath.Add(function(player)
    if windows[player] then windows[player]:close(); windows[player]=nil end
    ready[player]=nil; requested[player]=nil; prompted[player]=nil
end)
