-- Wick's Stances and Things
-- Swap.lua: two keys. One puts your two-hander in your hands, the other
-- your one-hander and shield.
--
-- A warrior carries both sets and swaps between them a dozen times a
-- session: the two-hander for the pull, the shield when something
-- turns on the healer, the two-hander again. Defensive Stance wants
-- the shield and Berserker wants the two-hander, and the stance strip
-- is right there, so the keys sit beside it. None of that can be
-- automatic. Equipping is a protected action, so an addon that watched
-- for a reason to swap and moved the weapons itself would be blocked.
-- What an addon can do is keep two macros right: secure buttons whose
-- text is rewritten out of combat, which is what these are. The keys
-- themselves are not tied to any spell; press one and the set goes on.
--
-- Three decisions worth keeping:
--
-- Pieces are addressed by item id rather than by name, so two maces
-- called the same thing cannot pick the wrong one.
--
-- The keys remember what you wore. Put a two-hander on by hand and the
-- two-hander key reaches for that one from then on, even with a better
-- one in the bag you have not decided about yet. A pin overrides the
-- memory, and with neither the best carried piece is used.
--
-- Each macro names where the set should end up rather than describing
-- a move. Pressing one twice does nothing the second time, and neither
-- can get out of step with what you are actually wearing.

local ADDON, ns = ...
if not WickCore then return end   -- said once in Core.lua
local Core = WickCore
local D = Core.Dialect

local Swap = {}
ns.swap = Swap

local MAIN, OFF = 16, 17

-- The kit's three kinds of piece, by where the client says they go.
local KIND_OF_LOC = {
    INVTYPE_2HWEAPON       = "twoHand",
    INVTYPE_WEAPON         = "oneHand",
    INVTYPE_WEAPONMAINHAND = "oneHand",
    INVTYPE_SHIELD         = "shield",
}
Swap.KINDS = { "twoHand", "oneHand", "shield" }
Swap.LABEL = { twoHand = "two-hander", oneHand = "one-hander", shield = "shield" }

local function db()
    return ns.A and ns.A.db and ns.A.db.profile or {}
end

-- What was last worn, per character.
local function sets()
    local A = ns.A
    local c = A and A.db and A.db.char
    if c then c.sets = c.sets or {}; return c.sets end
    local p = db()
    p.sets = p.sets or {}
    return p.sets
end

local function kindOf(id)
    if not id then return nil end
    local info = D.GetItemInfoInstant(id)
    return info and KIND_OF_LOC[info.equipLoc] or nil
end

local function worn(slot)
    return GetInventoryItemID and GetInventoryItemID("player", slot) or nil
end

-- ============================================================
-- What is in your hands
-- ============================================================

function Swap:Hands()
    local m, o = worn(MAIN), worn(OFF)
    local mk, ok = kindOf(m), kindOf(o)
    return {
        main = m, off = o, mainKind = mk, offKind = ok,
        twoHanded = mk == "twoHand",
        boarded   = mk == "oneHand" and ok == "shield",
    }
end

-- Remember the pieces you chose by wearing them.
function Swap:Learn(h)
    local s = sets()
    if h.twoHanded then s.twoHand = h.main end
    if h.mainKind == "oneHand" then s.oneHand = h.main end
    if h.offKind == "shield" then s.shield = h.off end
end

-- Everything carried of a kind, worn or bagged, best first. A piece the
-- client has not described yet counts at level zero and comes back up
-- the list once GET_ITEM_INFO_RECEIVED lands.
function Swap:Carried(kind)
    local list, seen = {}, {}
    local function consider(id)
        if not id or seen[id] then return end
        if kindOf(id) ~= kind then return end
        seen[id] = true
        local it = D.GetItemInfo(id)
        if not it then self.incomplete = true end
        list[#list + 1] = {
            id = id, name = it and it.name, icon = it and it.icon,
            itemLevel = it and it.itemLevel or 0,
        }
    end
    consider(worn(MAIN))
    consider(worn(OFF))
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local n = D.GetContainerNumSlots(bag) or 0
        for slot = 1, n do consider(D.GetContainerItemID(bag, slot)) end
    end
    table.sort(list, function(a, b)
        if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
        return a.id < b.id
    end)
    return list
end

-- The piece a key reaches for: pinned while it is carried, otherwise
-- the one you last wore while it is carried, otherwise the best one.
function Swap:Pick(kind)
    local list = self:Carried(kind)
    if #list == 0 then return nil end
    local pinned = db().pinned and db().pinned[kind]
    if pinned then
        for _, e in ipairs(list) do
            if e.id == pinned then e.pinned = true; return e end
        end
    end
    local remembered = sets()[kind]
    if remembered then
        for _, e in ipairs(list) do if e.id == remembered then return e end end
    end
    return list[1]
end

-- ============================================================
-- The macros
-- ============================================================

-- The two-hander key names the main hand only: the client puts the
-- shield away by itself to make room. The shield key names both hands,
-- and in that order, so the two-hander is out before the shield goes
-- on. /equipslot works in combat on this client, so a key pressed
-- mid-fight still does its job with the ids it already holds.
function Swap:Text(which)
    local c = self.choice or {}
    if which == "twoHand" then
        if not c.twoHand then return "" end
        return ("/equipslot %d item:%d"):format(MAIN, c.twoHand.id)
    end
    if not (c.oneHand and c.shield) then return "" end
    return ("/equipslot %d item:%d\n/equipslot %d item:%d")
        :format(MAIN, c.oneHand.id, OFF, c.shield.id)
end

-- Why a key is empty, in words.
function Swap:Why(which)
    local c = self.choice or {}
    if which == "twoHand" then
        return c.twoHand and nil or "no two-hander carried"
    end
    if not c.oneHand then return "no one-hander carried" end
    if not c.shield then return "no shield carried" end
    return nil
end

-- What the strip draws: the icon of the piece each key puts in your
-- hands, and whether that set is already on.
function Swap:Faces()
    local c, h = self.choice or {}, self.hands or {}
    local function icon(e)
        if not e then return nil end
        if e.icon then return e.icon end
        local info = D.GetItemInfoInstant(e.id)
        return info and info.icon or nil
    end
    return {
        twoHand = c.twoHand and { id = c.twoHand.id, icon = icon(c.twoHand), live = h.twoHanded == true } or nil,
        shield  = (c.oneHand and c.shield)
            and { id = c.shield.id, icon = icon(c.shield), weapon = c.oneHand.id, live = h.boarded == true } or nil,
    }
end

function Swap:Shown()
    return ns.isWarrior and db().swap ~= false
end

-- ============================================================
-- The keys
-- ============================================================

local buttons = { twoHand = {}, shield = {} }
local pending = false

function Swap:RegisterButton(which, b)
    local list = buttons[which]
    if not list then return end
    list[#list + 1] = b
    b:SetAttribute("type", "macro")
    self:Update()
end

function Swap:Update()
    -- Reading costs nothing and the strip only draws, so both happen
    -- whatever the client will let us write.
    self.incomplete = false
    local h = self:Hands()
    self.hands = h
    self:Learn(h)
    self.choice = {
        twoHand = self:Pick("twoHand"),
        oneHand = self:Pick("oneHand"),
        shield  = self:Pick("shield"),
    }
    if ns.UI and ns.UI.RefreshSwap then ns.UI:RefreshSwap() end

    -- A secure attribute cannot be written in combat. Nothing is lost
    -- by waiting: the keys already name the right pieces, only the
    -- mark on the strip was stale.
    if InCombatLockdown() then pending = true return end
    pending = false
    self.macro = {}
    local on = db().swap ~= false
    for which, list in pairs(buttons) do
        local text = on and self:Text(which) or ""
        self.macro[which] = text
        for _, b in ipairs(list) do b:SetAttribute("macrotext", text) end
    end
end

-- Look again in a moment, while a key is still empty. None of the
-- events below is promised to arrive after the one read that failed,
-- so the keys would stay empty on a quiet login.
function Swap:Retry(left)
    left = left or 6
    self:Update()
    local c = self.choice or {}
    if (c.twoHand and c.oneHand and c.shield) or left <= 0 then return end
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() Swap:Retry(left - 1) end)
    end
end

function Swap:Init()
    if not ns.isWarrior or self.inited then return end
    self.inited = true
    for which, name in pairs({ twoHand = "WicksStancesTwoHandButton",
                               shield  = "WicksStancesShieldButton" }) do
        local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
        b:SetSize(1, 1)
        b:SetPoint("CENTER")
        b:SetAlpha(0)
        b:EnableMouse(false)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:Show()
        self:RegisterButton(which, b)
    end

    ns.RegisterEvents({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD",
                        "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED",
                        -- Equipment arriving, as against equipment
                        -- changing. At login the second never fires.
                        "UNIT_INVENTORY_CHANGED",
                        -- Which piece is which needs the item described,
                        -- and that lands separately.
                        "GET_ITEM_INFO_RECEIVED" })
    ns:On("PLAYER_EQUIPMENT_CHANGED", function() Swap:Update() end)
    ns:On("BAG_UPDATE_DELAYED", function() Swap:Update() end)
    ns:On("PLAYER_ENTERING_WORLD", function() Swap:Retry() end)
    ns:On("UNIT_INVENTORY_CHANGED", function(_, unit)
        if unit == nil or unit == "player" then Swap:Update() end
    end)
    ns:On("GET_ITEM_INFO_RECEIVED", function()
        -- Only while a piece is still undescribed. This one fires for
        -- every item the client gets round to describing.
        if Swap.incomplete then Swap:Update() end
    end)
    ns:On("PLAYER_REGEN_ENABLED", function() if pending then Swap:Update() end end)
    self:Retry()
end

-- ============================================================
-- /wst swap and /wst pin
-- ============================================================

local function kindFrom(word)
    word = (word or ""):lower()
    if word == "2h" or word == "twohand" or word == "two" then return "twoHand" end
    if word == "1h" or word == "onehand" or word == "one" or word == "weapon" then return "oneHand" end
    if word == "shield" or word == "board" then return "shield" end
    return nil
end

function Swap:Command(rest, print_)
    rest = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = rest:lower()
    if lower == "on" or lower == "off" then
        db().swap = (lower == "on")
        self:Update()
        return print_("weapon swap keys " .. (db().swap and "on" or "off") .. ".")
    end
    return self:Report(print_)
end

function Swap:Pin(rest, print_)
    rest = (rest or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local word, value = rest:match("^(%S+)%s*(.*)$")
    local kind = kindFrom(word)
    if not kind then
        return print_("which piece? /wst pin 2h [item link], /wst pin 1h [item link], /wst pin shield clear")
    end
    local p = db()
    p.pinned = p.pinned or {}
    if value == "" then
        local pick = self.choice and self.choice[kind]
        return print_(("%s: %s%s"):format(self.LABEL[kind],
            pick and (D.GetItemNameByID(pick.id) or ("item " .. pick.id)) or "nothing carried",
            p.pinned[kind] and "  (pinned)" or ""))
    end
    local lv = value:lower()
    if lv == "clear" or lv == "off" then
        p.pinned[kind] = nil
        self:Update()
        return print_(self.LABEL[kind] .. " unpinned.")
    end
    local id = tonumber(value) or tonumber(value:match("item:(%d+)") or "")
    if not id then return print_("give an item link or item ID.") end
    p.pinned[kind] = id
    self:Update()
    print_(("%s pinned to %s."):format(self.LABEL[kind], D.GetItemNameByID(id) or ("item " .. id)))
end

function Swap:Report(print_)
    if db().swap == false then
        print_("weapon swap keys are off. /wst swap on switches them back.")
    end
    local name = function(e)
        if not e then return "none carried" end
        return (D.GetItemNameByID(e.id) or ("item " .. tostring(e.id))) .. (e.pinned and " (pinned)" or "")
    end
    local c, h = self.choice or {}, self.hands or {}
    print_(("two-hander: %s   one-hander: %s   shield: %s"):format(name(c.twoHand), name(c.oneHand), name(c.shield)))
    print_("wearing: " .. (h.twoHanded and "the two-hander" or (h.boarded and "sword and board" or "neither set")))
    for _, which in ipairs({ "twoHand", "shield" }) do
        local text = self.macro and self.macro[which]
        local label = which == "twoHand" and "two-hander key" or "shield key"
        if text and text ~= "" then
            print_(label .. ": " .. text:gsub("\n", " | "))
        else
            print_(label .. ": empty" .. (self:Why(which) and (", " .. self:Why(which)) or ""))
        end
    end
    print_("bind them under Key Bindings, Wick's Stances and Things.")
end

function Swap:OptionRow(page, y)
    local O = Core.Options
    y = O:Heading(page, "Weapon swap", y)
    y = O:Check(page, "Keep the swap keys loaded",
        function() return db().swap ~= false end,
        function(v) db().swap = v; Swap:Update() end, y)
    y = O:Note(page, "Two keys, tied to nothing. One puts your two-hander in your hands, the other your one-hander and shield. They remember what you last wore, so a new weapon needs nothing done to it beyond putting it on once; /wst pin 2h with an item link makes a key reach for one piece and no other. Swapping costs you a swing. Bind them under Key Bindings.", y)
    return y
end
