-- Wick's Stances and Things
-- Stances.lua: which stance you are in, and the macro that gets you to the
-- one an ability needs.
--
-- A warrior's loadout is a stance. Half the class is locked behind the
-- wrong one, and the cost of that is a second spent remembering which.
-- This reads the stance out of the shapeshift API, the same place the
-- druid kit reads forms from, and builds the macro text for a button
-- that puts you where an ability wants you.
--
-- Nothing here tracks combat. Stance is a loadout, readable at any time
-- and not a secret value, so the kit stays inside Forever's addon rules.

local ADDON, ns = ...
local Core = WickCore
local D = Core.Dialect

local Stances = {}
ns.Stances = Stances

-- Index as the shapeshift bar reports it. Warriors learn them in this
-- order and the indexes do not move.
Stances.BATTLE, Stances.DEFENSIVE, Stances.BERSERKER = 1, 2, 3

local SPELL = {
    [1] = { name = "Battle Stance",     id = 2457,  icon = 132349 },
    [2] = { name = "Defensive Stance",  id = 71,    icon = 132341 },
    [3] = { name = "Berserker Stance",  id = 2458,  icon = 132275 },
}
Stances.SPELL = SPELL

-- What each ability insists on. Anything not listed needs no stance and
-- the macro casts it where you stand, which is the right answer for
-- Heroic Strike, Execute, Hamstring and the rest.
--
-- Shield Bash and Sunder Armor work in more than one stance, so they are
-- deliberately absent: moving you for an ability you could already use
-- would be worse than doing nothing.
local NEEDS = {
    ["Charge"]          = 1,
    ["Overpower"]       = 1,
    ["Thunder Clap"]    = 1,
    ["Mocking Blow"]    = 1,
    ["Retaliation"]     = 1,
    ["Taunt"]           = 2,
    ["Shield Wall"]     = 2,
    ["Shield Block"]    = 2,
    ["Revenge"]         = 2,
    ["Disarm"]          = 2,
    ["Last Stand"]      = 2,
    ["Intercept"]       = 3,
    ["Whirlwind"]       = 3,
    ["Pummel"]          = 3,
    ["Berserker Rage"]  = 3,
    ["Recklessness"]    = 3,
}
Stances.NEEDS = NEEDS

function Stances:StanceFor(ability)
    if not ability then return nil end
    return NEEDS[ability]
end

-- Every ability this kit knows how to route, in stance order, for the
-- options list and for the slash command's help.
function Stances:Routable()
    local out = {}
    for name, idx in pairs(NEEDS) do out[#out + 1] = { name = name, stance = idx } end
    table.sort(out, function(a, b)
        if a.stance ~= b.stance then return a.stance < b.stance end
        return a.name < b.name
    end)
    return out
end

-- ============================================================
-- Reading the stance
-- ============================================================

-- nil when this character has no stance bar at all: a warrior below ten,
-- or any other class looking at the kit.
function Stances:Current()
    local f = rawget(_G, "GetShapeshiftForm")
    if not f then return nil end
    local ok, idx = pcall(f)
    if not ok or type(idx) ~= "number" or idx == 0 then return nil end
    return idx
end

function Stances:Count()
    local f = rawget(_G, "GetNumShapeshiftForms")
    if not f then return 0 end
    local ok, n = pcall(f)
    return (ok and type(n) == "number") and n or 0
end

-- The stance's own name, from the client, falling back to ours. Reading
-- theirs means a locale that is not English still reads right.
function Stances:NameOf(index)
    local info = rawget(_G, "GetShapeshiftFormInfo")
    if info then
        local ok, _, name = pcall(info, index)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return SPELL[index] and SPELL[index].name or ("Stance " .. tostring(index))
end

function Stances:IconOf(index)
    local info = rawget(_G, "GetShapeshiftFormInfo")
    if info then
        local ok, tex = pcall(info, index)
        if ok and tex then return tex end
    end
    return SPELL[index] and SPELL[index].icon or nil
end

-- Has the character actually learned this stance yet.
function Stances:HasStance(index)
    return index <= self:Count()
end

-- ============================================================
-- The macro
-- ============================================================
-- Two lines, and it takes two presses when you are in the wrong stance:
-- the game applies a stance change and a cast from the same press as the
-- change only. That is the client's rule, not a shortcut here, and
-- pretending otherwise with a castsequence only makes it unpredictable.
-- So the first press moves you and the second swings.
--
-- In the right stance already, one press casts. That is the common case
-- and it costs nothing.

function Stances:MacroFor(ability)
    if not ability or ability == "" then return "" end
    local want = self:StanceFor(ability)
    if not want then
        -- No stance requirement: cast it where you stand.
        return ("#showtooltip %s\n/cast %s"):format(ability, ability)
    end
    local stance = SPELL[want]
    return ("#showtooltip %s\n/cast [nostance:%d] %s\n/cast [stance:%d] %s")
        :format(ability, want, stance.name, want, ability)
end

-- A plain stance swap, for the three buttons on the strip.
function Stances:SwapMacro(index)
    local s = SPELL[index]
    if not s then return "" end
    return ("#showtooltip %s\n/cast %s"):format(s.name, s.name)
end

function Stances:Init()
    if self.inited then return end
    self.inited = true
    ns.RegisterEvents({ "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD" })
    local function refresh()
        if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end
    end
    ns:On("UPDATE_SHAPESHIFT_FORM", refresh)
    ns:On("UPDATE_SHAPESHIFT_FORMS", refresh)
    ns:On("PLAYER_ENTERING_WORLD", refresh)
end
