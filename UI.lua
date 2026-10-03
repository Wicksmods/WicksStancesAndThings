-- Wick's Stances and Things
-- UI.lua: the stance strip.
--
-- One 30px row: three stance buttons and a smart key. The stance you are
-- in is lit in fel green, the ones you have not learned yet are dim. The
-- smart key carries whichever ability you bound to it and shows the
-- stance that ability wants, so you can see at a glance whether pressing
-- it will move you or swing.
--
-- Every button is a SecureActionButton with macro text, which is the only
-- way an addon may cast anything. Macro text is rewritten out of combat
-- only; in combat the buttons keep whatever they were last given, which
-- is the right answer anyway since the binding does not change mid-fight.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local Chrome, R = Core.Chrome, Core.Restrict
local C = Chrome.Colors

local UI = {}
ns.UI = UI

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DIM = { 0.35, 0.33, 0.40, 1 }

local STRIP_H = 30
local BTN     = 26
local SMART_W = 116
local PAD     = 4

local function tint(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

-- ============================================================
-- Building
-- ============================================================

local function makeSecure(parent, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetAttribute("type1", "macro")
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- The lit ring for the stance you are in. A border of our own rather
    -- than Blizzard's, so it takes the theme.
    b.ring = {}
    for _, p in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
                         { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
        local t = Chrome:Texture(b, "OVERLAY", C.border)
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if p[3] then t:SetWidth(p[3]) end
        if p[4] then t:SetHeight(p[4]) end
        b.ring[#b.ring + 1] = t
    end
    return b
end

local function ringColor(b, c)
    for _, t in ipairs(b.ring) do t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

-- Each of the two swap keys. The icon is the piece that key puts in
-- your hands; the fel edge means that set is already on.
local function makeSwap(parent, which, name)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(BTN, BTN)
    b:RegisterForClicks("AnyUp", "AnyDown")
    ns.swap:RegisterButton(which, b)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.live = Chrome:Texture(b, "OVERLAY", C.fel)
    b.live:SetPoint("BOTTOMLEFT", 1, 1)
    b.live:SetPoint("BOTTOMRIGHT", -1, 1)
    b.live:SetHeight(2)
    b.live:Hide()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.10)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        local faces = ns.swap:Faces()
        local face = faces and faces[which]
        GameTooltip:SetText(which == "twoHand" and "Two-hander" or "Sword and board", 1, 1, 1)
        if not face then
            GameTooltip:AddLine(tostring(ns.swap:Why(which) or "nothing to swap"), 0.5, 0.5, 0.5, true)
        else
            local D = Core.Dialect
            local name = D.GetItemNameByID(face.id) or "that piece"
            if which == "twoHand" then
                GameTooltip:AddLine(name .. " to your main hand.", 0.8, 0.8, 0.8, true)
            else
                local weapon = D.GetItemNameByID(face.weapon) or "your one-hander"
                GameTooltip:AddLine(weapon .. " and " .. name .. ".", 0.8, 0.8, 0.8, true)
            end
            if face.live then GameTooltip:AddLine("Already on.", 0.5, 0.5, 0.5, true) end
            GameTooltip:AddLine("Costs a swing. /wst pin to choose a piece by hand.", 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

function UI:BuildStrip()
    if self.strip then return self.strip end
    local db = ns.db and ns.db.profile

    local f = CreateFrame("Frame", "WicksStancesStrip", UIParent)
    self.strip = f
    -- Said out loud at build time. A protected frame cannot be shown or
    -- hidden once a fight starts, so whether the swap keys exist is
    -- settled here; switching them off takes a reload.
    local swapW = (ns.swap and ns.swap:Shown()) and (3 + (BTN + 2) * 2) or 0
    f:SetSize(PAD + (BTN + 2) * 3 + 1 + SMART_W + swapW + PAD, STRIP_H)
    f:SetPoint("CENTER", 0, -200)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s)
        -- A lock stops a nudge, not a deliberate move: shift overrides it.
        if Chrome:DragAllowed(db and db.stripLocked) then s:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        if db then db.strip = db.strip or {}; Chrome:SavePosition(s, db.strip) end
    end)
    if db and db.strip and db.strip.point then Chrome:RestorePosition(f, db.strip) end

    local bg = Chrome:Texture(f, "BACKGROUND", C.voidBG); bg:SetAllPoints()
    Chrome:AddBorder(f)

    -- Three stances.
    f.stance = {}
    for i = 1, 3 do
        local b = makeSecure(f, "WicksStancesButton" .. i)
        b:SetSize(BTN, BTN)
        b:SetPoint("LEFT", PAD + (i - 1) * (BTN + 2), 0)
        b.index = i
        b:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:SetText(ns.Stances:NameOf(s.index), 1, 1, 1)
            if not ns.Stances:HasStance(s.index) then
                GameTooltip:AddLine("Not learned yet.", 0.6, 0.6, 0.6)
            elseif ns.Stances:Current() == s.index then
                GameTooltip:AddLine("You are in it.", C.fel[1], C.fel[2], C.fel[3])
            else
                GameTooltip:AddLine("Click to swap.", 0.5, 0.5, 0.5)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.stance[i] = b
    end

    local div = Chrome:Texture(f, "ARTWORK", C.border)
    div:SetPoint("TOPLEFT", f.stance[3], "TOPRIGHT", 2, 0)
    div:SetPoint("BOTTOMLEFT", f.stance[3], "BOTTOMRIGHT", 2, 0)
    div:SetWidth(1)

    -- The smart key: icon plus the ability's name and the stance it wants.
    local smart = makeSecure(f, "WicksStancesSmartButton")
    smart:SetSize(BTN, BTN)
    smart:SetPoint("LEFT", f.stance[3], "RIGHT", 5, 0)
    f.smart = smart

    f.smartText = Chrome:Text(f, 11)
    f.smartText:SetPoint("LEFT", smart, "RIGHT", 5, 5)
    f.smartText:SetPoint("RIGHT", -PAD, 5)
    f.smartText:SetJustifyH("LEFT")
    f.smartText:SetWordWrap(false)

    f.smartNote = Chrome:Text(f, 9, C.muted)
    f.smartNote:SetPoint("LEFT", smart, "RIGHT", 5, -6)
    f.smartNote:SetPoint("RIGHT", -PAD, -6)
    f.smartNote:SetJustifyH("LEFT")
    f.smartNote:SetWordWrap(false)

    smart:SetScript("OnEnter", function(s)
        local ability = (ns.db and ns.db.profile.smartAbility) or ""
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(ability ~= "" and ability or "No ability bound", 1, 1, 1)
        local want = ns.Stances:StanceFor(ability)
        if want then
            local here = ns.Stances:Current() == want
            GameTooltip:AddLine(("Needs %s."):format(ns.Stances:NameOf(want)), 0.83, 0.78, 0.63)
            GameTooltip:AddLine(here and "You are in it: one press uses the ability."
                or "One press to swap, another to use it.",
                here and C.fel[1] or 0.85, here and C.fel[2] or 0.65, here and C.fel[3] or 0.25)
        elseif ability ~= "" then
            GameTooltip:AddLine("Needs no stance: cast where you stand.", 0.5, 0.5, 0.5)
        end
        GameTooltip:AddLine("/wst bind <ability> to change it.", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    smart:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The two weapon swap keys, after the smart key.
    if swapW > 0 then
        -- Anchored to the strip by offset, never to the divider: a
        -- protected button cannot be anchored to a texture.
        local x = PAD + (BTN + 2) * 3 + 1 + SMART_W + 1
        local sdiv = Chrome:Texture(f, "ARTWORK", C.border)
        sdiv:SetPoint("TOP", f, "TOPLEFT", x, -2)
        sdiv:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, 2)
        sdiv:SetWidth(1)
        f.swapTwo = makeSwap(f, "twoHand", "WicksStancesTwoHandButton")
        f.swapTwo:SetPoint("LEFT", f, "LEFT", x + 3, 0)
        f.swapShield = makeSwap(f, "shield", "WicksStancesShieldButton")
        f.swapShield:SetPoint("LEFT", f, "LEFT", x + 3 + BTN + 2, 0)
    end

    -- Right-click anywhere on the strip opens the kit, matching the other
    -- kits' launcher. The stance buttons are secure, so their right-click
    -- goes through the strip underneath rather than through them.
    f:SetScript("OnMouseUp", function(_, btn)
        if btn == "RightButton" then ns.A.kit:Toggle() end
    end)

    f:SetScript("OnShow", function() UI:Refresh() end)
    R:OnChange(function() if f:IsShown() then UI:Refresh() end end)

    self:UpdateMacros()
    return f
end

-- ============================================================
-- Macro text
-- ============================================================
-- Out of combat only. A secure button refuses attribute changes in
-- combat, and the binding does not change mid-fight anyway.

function UI:UpdateMacros()
    local f = self.strip
    if not f then return end
    if InCombatLockdown and InCombatLockdown() then
        self.macrosStale = true
        return
    end
    self.macrosStale = nil
    for i = 1, 3 do
        local m = ns.Stances:SwapMacro(i)
        f.stance[i]:SetAttribute("macrotext", m)
        f.stance[i]:SetAttribute("macrotext1", m)
    end
    local ability = (ns.db and ns.db.profile.smartAbility) or ""
    local m = ns.Stances:MacroFor(ability)
    f.smart:SetAttribute("macrotext", m)
    f.smart:SetAttribute("macrotext1", m)
    self:Refresh()
end

-- ============================================================
-- Painting
-- ============================================================

function UI:Refresh()
    local f = self.strip
    if not f or not f:IsShown() then return end
    if self.macrosStale then self:UpdateMacros() end

    local current = ns.Stances:Current()
    for i = 1, 3 do
        local b = f.stance[i]
        b.icon:SetTexture(ns.Stances:IconOf(i) or QUESTION)
        local known = ns.Stances:HasStance(i)
        b.icon:SetDesaturated(not known)
        b.icon:SetAlpha(known and 1 or 0.35)
        ringColor(b, (current == i) and C.fel or C.border)
    end

    local ability = (ns.db and ns.db.profile.smartAbility) or ""
    local want = ns.Stances:StanceFor(ability)
    f.smart.icon:SetTexture(ns.Stances:IconOf(want or current or 1) or QUESTION)
    f.smart.icon:SetDesaturated(ability == "")
    ringColor(f.smart, (want and current == want) and C.fel or C.border)

    f.smartText:SetText(ability ~= "" and ability or "no ability bound")
    tint(f.smartText, ability ~= "" and C.text or DIM)
    if want then
        local here = current == want
        f.smartNote:SetText(here and "ready" or ("swap to " .. ns.Stances:NameOf(want):gsub(" Stance", "")))
        tint(f.smartNote, here and C.fel or { 0.85, 0.65, 0.25, 1 })
    elseif ability ~= "" then
        f.smartNote:SetText("any stance")
        tint(f.smartNote, C.muted)
    else
        f.smartNote:SetText("/wst bind <ability>")
        tint(f.smartNote, C.muted)
    end
    self:RefreshSwap()
end

-- Icons and the live edge only. Nothing here shows, hides or moves a
-- protected frame, so it is safe to run mid-fight.
function UI:RefreshSwap()
    local f = self.strip
    if not (f and f.swapTwo) then return end
    local faces = ns.swap and ns.swap:Faces()
    for which, b in pairs({ twoHand = f.swapTwo, shield = f.swapShield }) do
        local face = faces and faces[which]
        b.icon:SetTexture(face and face.icon or QUESTION)
        -- A set it cannot make goes grey rather than disappearing, so
        -- the strip does not change shape on you.
        b.icon:SetDesaturated(face == nil)
        b.icon:SetAlpha(face and 1 or 0.35)
        b.live:SetShown(face ~= nil and face.live == true)
    end
end

-- ============================================================
-- Showing and hiding
-- ============================================================

function UI:ApplyStripVisibility()
    local db = ns.db and ns.db.profile
    local want = ns.isWarrior and db and db.showStrip ~= false
    if want then
        self:BuildStrip()
        self.strip:Show()
        self:Refresh()
    elseif self.strip then
        self.strip:Hide()
    end
end

function UI:SetStripLocked(locked)
    local db = ns.db and ns.db.profile
    if db then db.stripLocked = locked and true or false end
    ns.A:Print(locked and "strip locked." or "strip unlocked: drag it into place, then /wst lock.")
end

function UI:Toggle()
    local db = ns.db and ns.db.profile
    if not db then return end
    if not ns.isWarrior then
        ns.A:Print("the stance strip is for warriors. /wst kit has the talents and checklist.")
        return
    end
    db.showStrip = not (db.showStrip ~= false)
    self:ApplyStripVisibility()
end

function UI:Init()
    self:ApplyStripVisibility()
    -- Macro text could not be written while the character was in combat
    -- at login; write it the moment that clears.
    ns.RegisterEvents({ "PLAYER_REGEN_ENABLED" })
    ns:On("PLAYER_REGEN_ENABLED", function()
        if UI.macrosStale then UI:UpdateMacros() end
    end)
end
