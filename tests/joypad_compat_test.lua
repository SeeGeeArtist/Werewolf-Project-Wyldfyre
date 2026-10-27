local root=assert(arg[1])
function require() end
local checks=0
local function check(x,s) checks=checks+1; assert(x,s) end
ISAtomUIJoypad={toString=function(self)
    if self.name=="" then
        error("attempted index: getSimpleName of non-table: class zombie.ui.AtomUI")
    end
    return self.name
end}
local focus
local function transfer(widget)
    local diagnostic=widget:toString()
    focus=widget
    return diagnostic
end
local unnamed=setmetatable({name=""},{__index=ISAtomUIJoypad})
local ok=pcall(transfer,unnamed)
check(not ok and focus==nil,"reproduce observed exception aborting focus transfer")
dofile(root.."/42/media/lua/client/WTAGarouJoypadCompat.lua")
check(transfer(unnamed)=="AtomUI" and focus==unnamed,"bad label no longer aborts focus")
local named=setmetatable({name="PrintMedia"},{__index=ISAtomUIJoypad})
check(transfer(named)=="PrintMedia" and focus==named,"successful native label unchanged")
-- A second module load still has a finite wrapper and preserves names.
dofile(root.."/42/media/lua/client/WTAGarouJoypadCompat.lua")
check(transfer(unnamed)=="AtomUI","reload-safe fallback")
check(transfer(named)=="PrintMedia","reload-safe native path")
print("PASS: "..checks.." AtomUI diagnostic/focus assertions.")
