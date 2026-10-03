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
if not WickCore then return end   -- said once in Core.lua
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

-- ============================================================
-- The kick key
-- ============================================================
-- One key for the interrupt that fits the stance and the hands you are
-- in: Pummel in Berserker, Shield Bash in Battle or Defensive with a
-- shield on, and with no shield there a first press into Berserker and a
-- second to Pummel, the same two-press rule as the smart key.
--
-- Who it hits, in order: the enemy under your mouse, your focus, your
-- target, then the enemy you are facing (the soft target). Your target
-- comes before the soft target so a kick never leaves the enemy you chose
-- for one you only happen to face. Nothing here targets or focuses
-- anything: the key casts at a unit and leaves your target and focus as
-- they were.
--
-- One press is one interrupt on one enemy. No macro can see who is
-- casting, and an addon cannot change who a key aims at mid-fight, so
-- the key goes where you point; nameplate castbars show where to point.

Stances.KICK_TARGETS = { "@mouseover,harm,nodead", "@focus,harm,nodead", "harm,nodead", "@softenemy,harm,nodead" }

-- The client's own name for shields, which [equipped:] is matched
-- against, so the condition holds in any language.
local function shieldsName()
    local E = rawget(_G, "Enum")
    local info = C_Item and C_Item.GetItemSubClassInfo
    if info and E and E.ItemClass and E.ItemArmorSubclass and E.ItemArmorSubclass.Shield then
        local ok, name = pcall(info, E.ItemClass.Armor, E.ItemArmorSubclass.Shield)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return "Shields"
end
Stances.ShieldsName = shieldsName

local function kickLine(spell, gate)
    local parts = {}
    for _, t in ipairs(Stances.KICK_TARGETS) do parts[#parts + 1] = "[" .. gate .. "," .. t .. "]" end
    return "/cast " .. table.concat(parts) .. " " .. spell
end

function Stances:KickMacro()
    local shields = shieldsName()
    return table.concat({
        kickLine("Pummel", "stance:" .. self.BERSERKER),
        kickLine("Shield Bash", ("nostance:%d,equipped:%s"):format(self.BERSERKER, shields)),
        ("/cast [nostance:%d,noequipped:%s] %s"):format(self.BERSERKER, shields, SPELL[self.BERSERKER].name),
    }, "\n")
end

-- What one press does right now: the spell, and whether that press only
-- changes stance. nil when it can do nothing (no shield on, and no
-- Berserker Stance learned yet).
function Stances:KickNow(shieldOn)
    if self:Current() == self.BERSERKER then return "Pummel", false end
    if shieldOn then return "Shield Bash", false end
    if self:HasStance(self.BERSERKER) then return SPELL[self.BERSERKER].name, true end
    return nil
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
