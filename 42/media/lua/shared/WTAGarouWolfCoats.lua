require "WTAGarouDefinitions"
-- Add one entry for each shipped PNG (server and clients use the same list).
-- Example: brown = {label="Brown", path="media/textures/Body/WTAGarou_Wolf_Brown.png"},
-- No Java rebuild needed. PNG filename suffix: letters, numbers, _ or -.
-- Crinos uses the same wolf UV atlas on its static head, and the shared
-- human-UV body atlas for both sexes. No separate CrinosHead or F_ PNGs.
-- 0.4.67: crinosLegs / crinosTail name the Body/ PNGs on the digitigrade
-- legs and the optional tail. 0.4.91: the (own, generated) legs mesh is
-- UV-mapped on the vanilla body atlas, so crinosLegs IS the coat's
-- CrinosBody texture that the author paints (claw dot on the foot island
-- included). 0.4.94: the author's tail mesh is UV-mapped on the wolf atlas,
-- so crinosTail is the coat's Wolf PNG, like the Crinos head. No
-- CrinosTail_<Coat> PNGs. Legs and tail meshes are unisex.
WTAGarou.WolfCoats = {
    default = {label="Timber", path="media/textures/Body/WTAGarou_Wolf_Timber.png",
        crinosBody="WTAGarou_CrinosBody_Timber", crinosHead="WTAGarou_Wolf_Timber",
        crinosLegs="WTAGarou_CrinosBody_Timber", crinosTail="WTAGarou_Wolf_Timber"},
    brown = {label="Brown", path="media/textures/Body/WTAGarou_Wolf_Brown.png",
        crinosBody="WTAGarou_CrinosBody_Brown", crinosHead="WTAGarou_Wolf_Brown",
        crinosLegs="WTAGarou_CrinosBody_Brown", crinosTail="WTAGarou_Wolf_Brown"},
    blonde = {label="Blonde", path="media/textures/Body/WTAGarou_Wolf_Blonde.png",
        crinosBody="WTAGarou_CrinosBody_Blonde", crinosHead="WTAGarou_Wolf_Blonde",
        crinosLegs="WTAGarou_CrinosBody_Blonde", crinosTail="WTAGarou_Wolf_Blonde"},
    brindle = {label="Brindle", path="media/textures/Body/WTAGarou_Wolf_Brindle.png",
        crinosBody="WTAGarou_CrinosBody_Brindle", crinosHead="WTAGarou_Wolf_Brindle",
        crinosLegs="WTAGarou_CrinosBody_Brindle", crinosTail="WTAGarou_Wolf_Brindle"},
    white = {label="White", path="media/textures/Body/WTAGarou_Wolf_White.png",
        crinosBody="WTAGarou_CrinosBody_White", crinosHead="WTAGarou_Wolf_White",
        crinosLegs="WTAGarou_CrinosBody_White", crinosTail="WTAGarou_Wolf_White"},
    black = {label="Black", path="media/textures/Body/WTAGarou_Wolf_Black.png",
        crinosBody="WTAGarou_CrinosBody_Black", crinosHead="WTAGarou_Wolf_Black",
        crinosLegs="WTAGarou_CrinosBody_Black", crinosTail="WTAGarou_Wolf_Black"},
}
-- 0.4.67: the Crinos tail is a per-character choice (default: none, the
-- tail-less Crinos). Stored as data.crinosTail (true/nil) by the server in
-- multiplayer and mirrored in the VisualSnapshot rows.
function WTAGarou.CrinosTailOn(value)
    return value == true
end
function WTAGarou.ValidWolfCoat(key)
    return type(key) == "string" and WTAGarou.WolfCoats[key] ~= nil
end
function WTAGarou.WolfCoatKeys()
    local keys={}
    for key in pairs(WTAGarou.WolfCoats) do keys[#keys+1]=key end
    table.sort(keys,function(a,b)
        if a=="default" then return b~="default" end
        if b=="default" then return false end
        return a<b
    end)
    return keys
end
