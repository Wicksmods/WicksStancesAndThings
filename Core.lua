-- Wick's Stances and Things
-- Core.lua: WickCore addon object, saved variables, event dispatch, slash command.
--
-- The warrior kit for World of Warcraft: Forever. A warrior's setup is a
-- stance, a shout and the talents behind them. All three are readable out
-- of combat and none is a combat tracker, so the kit sits inside
-- Forever's addon rules. Through WickCore it adds the talent layer, the
-- pre-pull checklist and racials.

local ADDON, ns = ...

local Core = WickCore
if not Core then
    -- WickCore is missing or switched off.
    --
    -- The TOC asks for it with OptionalDeps rather than Dependencies on
    -- purpose. A hard dependency makes the client refuse to load this addon
    -- at all, so nothing of ours runs and the player is told nothing beyond
    -- a greyed line in the AddOns list. Loading anyway lets us say what is
    -- wrong and where to get it.
    --
    -- One line for the lot of them, not one per addon: with the whole suite
    -- installed and WickCore switched off, a line each would be a wall.
    local need = _G.WicksNeedCore
    if not need then
        need = {}
        _G.WicksNeedCore = need
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function()
            table.sort(need)
            print(("|cff4FC778Wick's Mods|r: %s %s WickCore, which is not installed or not switched on. It is in the same download as the rest of the suite: |cffD4C8A1wicksmods.com|r")
                :format(table.concat(need, ", "), #need == 1 and "needs" or "need"))
        end)
    end
    need[#need + 1] = "Wick's Stances and Things"
    return
end
local D, R = Core.Dialect, Core.Restrict

ns.version = "0.9.0"

local PROFILE_DEFAULTS = {
    smartAbility = "Charge",   -- what the smart key reaches for
    showStrip    = true,
    stripLocked  = true,
    strip        = {},
    kitWindow    = {},
}

local A = Core:NewAddon("WicksStancesAndThings", {
    title    = "Wick's Stances and Things",
    version  = ns.version,
    savedVar = "WicksStancesSaved",
    defaults = { profile = PROFILE_DEFAULTS, global = {} },
})
ns.A = A

-- ============================================================
-- Event dispatcher
-- ============================================================
local events = {}
function ns:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end

local frame = CreateFrame("Frame", "WicksStancesEvents")
ns.eventFrame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    if events[event] then
        for _, fn in ipairs(events[event]) do
            local ok, err = pcall(fn, event, ...)
            if not ok then A:Print(("error in %s: %s"):format(event, tostring(err))) end
        end
    end
end)
function ns.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end

local _, playerClass = UnitClass("player")
ns.isWarrior = playerClass == "WARRIOR"

ns.SPELL = {
    BATTLE_SHOUT      = 6673,
    COMMANDING_SHOUT  = 469,
    DEMORALIZING_SHOUT = 1160,
    BERSERKER_RAGE    = 18499,
}

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    ns.db = self.db
    self.db:On("OnProfileChanged", function()
        if ns.UI and ns.UI.ApplyStripVisibility then ns.UI:ApplyStripVisibility() end
        if ns.UI and ns.UI.UpdateMacros then ns.UI:UpdateMacros() end
    end)

    Core.Cooldowns:New(self, { key = "cooldownBar" })

    Core.Kit:New(self, {
        racials = true,
        checklist = {
            -- A shout is the one buff a warrior brings to their own pull,
            -- and either of the two counts.
            { label = "Shout up", aura = { "Battle Shout", "Commanding Shout" },
              cast = "Battle Shout", known = ns.SPELL.BATTLE_SHOUT },
            { label = "In a stance", check = function()
                if ns.Stances:Count() == 0 then return nil end
                return ns.Stances:Current() ~= nil
            end },
            { label = "Weapon equipped", check = function()
                local f = rawget(_G, "GetInventoryItemID")
                if not f then return nil end
                return f("player", 16) ~= nil
            end },
            { label = "Shield for Defensive", check = function()
                -- Only worth saying when the character actually tanks:
                -- a shield in the off hand, or nothing to report.
                local f = rawget(_G, "GetInventoryItemID")
                if not f then return nil end
                local id = f("player", 17)
                if not id then return nil end
                local _, _, _, _, _, classID, subClassID = D.GetItemInfoInstant(id)
                if classID ~= 4 then return nil end
                return subClassID == 6
            end },
        },
    })
end

function A:OnEnable()
    if not ns.isWarrior then
        self:Print("loaded (non-warrior: viewer mode).")
    else
        self:Print("loaded. /wst for the stance strip, /wst kit for talents and checklist.")
    end
    if ns.Stances and ns.Stances.Init then ns.Stances:Init() end
    if ns.UI and ns.UI.Init then ns.UI:Init() end

    self:RegisterLauncher({
        onClick = function(_, button)
            if button == "RightButton" then self.kit:Toggle()
            else ns.UI:Toggle() end
        end,
        tooltip = function(tt)
            tt:AddLine(Core.Chrome:TitleMarkup("Wick's Stances and Things"))
            tt:AddLine("Left-click: stances   Right-click: talents and checklist", 0.5, 0.5, 0.5)
        end,
    })

    if self.cooldowns then self.cooldowns:Init() end

    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local db = addon.db.profile
        local y = O:Heading(page, "Stance strip", 0)
        y = O:Check(page, "Show the stance strip", function() return db.showStrip ~= false end,
            function(v) db.showStrip = v; ns.UI:ApplyStripVisibility() end, y)
        y = O:Check(page, "Lock the strip", function() return db.stripLocked ~= false end,
            function(v) db.stripLocked = v end, y)
        y = O:Note(page, "Three stances and one smart key. The stance you are in is lit; click another to swap. Shift-drag moves the strip even when locked.", y)

        y = O:Heading(page, "The smart key", y - 6)
        y = O:Note(page, ("Set to %s. Change it with /wst bind <ability>. The key puts you in the stance that ability needs and then uses it, so from the wrong stance it takes two presses: the game will not change stance and swing off one. From the right stance it is a single press.")
            :format(db.smartAbility or "Charge"), y)
        y = O:Button(page, "Open strip", function() ns.UI:Toggle() end, y, 100)
        y = O:Button(page, "Open kit", function() addon.kit:Toggle() end, y, 100)
        if addon.cooldowns then y = addon.cooldowns:OptionRow(page, y - 6) end
        y = O:ProfileSection(page, addon, y - 8)
    end)
end

-- Keybinding entry points
BINDING_HEADER_WICKSSTANCES = "Wick's Stances and Things"
_G["BINDING_NAME_CLICK WicksStancesSmartButton:LeftButton"] = "Smart stance ability"
_G["BINDING_NAME_CLICK WicksStancesButton1:LeftButton"] = "Battle Stance"
_G["BINDING_NAME_CLICK WicksStancesButton2:LeftButton"] = "Defensive Stance"
_G["BINDING_NAME_CLICK WicksStancesButton3:LeftButton"] = "Berserker Stance"
BINDING_NAME_WICKSSTANCES_TOGGLE = "Toggle stance strip"
function WicksStancesAndThings_Toggle() if ns.UI then ns.UI:Toggle() end end

-- ============================================================
-- Slash command
-- ============================================================
A:RegisterSlash(function(_, msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = msg:lower()
    local db = A.db.profile

    if lower == "" or lower == "show" or lower == "toggle" then ns.UI:Toggle() return end
    if lower == "kit" or lower == "talents" or lower == "checklist" then A.kit:Toggle() return end
    if lower == "cd" or lower:match("^cd%s") then return A.cooldowns:Command(msg:match("^%a+%s*(.*)$")) end
    if lower == "options" or lower == "config" then A:OpenOptions() return end
    if lower == "strip" then
        db.showStrip = not (db.showStrip ~= false)
        ns.UI:ApplyStripVisibility()
        A:Print("strip " .. (db.showStrip and "shown" or "hidden") .. ".")
        return
    end
    if lower == "unlock" or lower == "move" then ns.UI:SetStripLocked(false) return end
    if lower == "lock" then ns.UI:SetStripLocked(true) return end

    if lower:match("^bind") then
        local want = msg:match("^%a+%s+(.+)$")
        if not want then
            A:Print(("the smart key uses %s. Set it with /wst bind <ability>."):format(db.smartAbility or "Charge"))
            A:Print("abilities it knows a stance for:")
            local line, count = {}, 0
            for _, e in ipairs(ns.Stances:Routable()) do
                line[#line + 1] = ("%s (%s)"):format(e.name, ns.Stances:NameOf(e.stance):gsub(" Stance", ""))
                count = count + 1
                if count % 3 == 0 then A:Print("  " .. table.concat(line, ", ")); line = {} end
            end
            if #line > 0 then A:Print("  " .. table.concat(line, ", ")) end
            A:Print("anything else is cast where you stand.")
            return
        end
        db.smartAbility = want
        local st = ns.Stances:StanceFor(want)
        ns.UI:UpdateMacros()
        A:Print(("smart key set to %s%s."):format(want,
            st and (", which needs " .. ns.Stances:NameOf(st)) or " (no stance needed)"))
        return
    end

    if lower == "status" or lower == "debug" then
        local cur = ns.Stances:Current()
        A:Print(("stances known: %d   currently: %s"):format(ns.Stances:Count(),
            cur and ns.Stances:NameOf(cur) or "none"))
        A:Print(("smart key: %s"):format(db.smartAbility or "none"))
        A:Print("macro: " .. (ns.Stances:MacroFor(db.smartAbility):gsub("\n", " | ")))
        return
    end

    A:Print("commands: show | strip | lock | unlock | kit | options | bind <ability> | cd | status")
end, "/wst", "/wstances")
