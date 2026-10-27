require "WTAGarouDefinitions"
-- Stable saved IDs, not client-supplied model or texture paths.
WTAGarou.WolfGearVariants = {
    Black = {harness="WTAGarou.WolfHarnessVisual", saddlebags="WTAGarou.WolfSaddlebagVisual"},
    Camo = {harness="WTAGarou.WolfHarnessVisualCamo", saddlebags="WTAGarou.WolfSaddlebagVisualCamo"},
}
function WTAGarou.ValidWolfGear(key)
    return type(key)=="string" and WTAGarou.WolfGearVariants[key]~=nil
end
function WTAGarou.WolfGearKey(key)
    return WTAGarou.ValidWolfGear(key) and key or "Black"
end
