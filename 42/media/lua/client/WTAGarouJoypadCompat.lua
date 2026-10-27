-- 0.4.47, Deck console: ISReadABook.displayPrintMedia -> setJoypadFocus ->
-- ISAtomUIJoypad.toString throws on class:getSimpleName for unnamed AtomUI.
-- This diagnostic label must not abort focus transfer. Preserve every
-- successful vanilla name; do not replace focus, input, or widget behavior.
require "ISUI/ISAtomUIJoypad"

local originalToString = ISAtomUIJoypad.toString
function ISAtomUIJoypad:toString()
    local ok, label = pcall(originalToString, self)
    if ok then return label end
    return "AtomUI"
end
