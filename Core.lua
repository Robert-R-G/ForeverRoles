--[[
	Forever Roles - marks, group roles, the right-click menu and group sharing.

	A player's role comes from, in order:
	  1. your own mark (right-click a player > Mark as), shared with groupmates
	     who also run Forever Roles;
	  2. the role the group assigned them (Group Finder / role check), when
	     auto-marking is on for that role in the settings.
	"No icon" is a mark too: it hides a player's icon even when the group has
	given them a role.

	Marks are kept by "Name-Realm". Forever can hand addons secret values; a
	name that cannot be read is simply not marked, never guessed.
]]

local ADDON, ns = ...

ns.ICON_FILE = [[Interface\LFGFrame\UI-LFG-ICON-ROLES]]
-- The sheet is 256 x 256 in 67-pixel cells: tank row 2 column 1, healer
-- row 1 column 2, DPS row 2 column 2 (measured from the client's own file).
local C = 67 / 256
ns.COORDS = {
	TANK = { 0, C, C, 2 * C },
	HEALER = { C, 2 * C, 0, C },
	DAMAGER = { C, 2 * C, C, 2 * C },
}
ns.LABEL = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
ns.ORDER = { "TANK", "HEALER", "DAMAGER" }

local DEFAULTS = {
	auto = { TANK = true, HEALER = true, DAMAGER = true },
	show = { nameplates = true, group = true, target = true, tooltip = true },
	share = true,
}

local function Readable(v)
	if issecretvalue and issecretvalue(v) then return nil end
	if canaccessvalue and not canaccessvalue(v) then return nil end
	return v
end
ns.Readable = Readable

function ns.Print(msg)
	print("|cff7fb2ffForever Roles|r: " .. tostring(msg))
end

--- An icon as chat/tooltip text.
function ns.IconString(role, size)
	local c = ns.COORDS[role]
	if not c then return "" end
	size = size or 14
	return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t", ns.ICON_FILE, size, size,
		c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local function Fill(target, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(target[k]) ~= "table" then target[k] = {} end
			Fill(target[k], v)
		elseif target[k] == nil then
			target[k] = v
		end
	end
end

local function InitDB()
	-- Settings are account-wide; the same table is kept per character too, so
	-- a client that drops one saved-variables file still has the other.
	local db = (type(ForeverRolesDB) == "table" and next(ForeverRolesDB) and ForeverRolesDB)
		or (type(ForeverRolesCharDB) == "table" and next(ForeverRolesCharDB) and ForeverRolesCharDB)
		or {}
	Fill(db, DEFAULTS)
	if type(db.marks) ~= "table" then db.marks = {} end
	ForeverRolesDB, ForeverRolesCharDB = db, db
	ns.db = db
end

---------------------------------------------------------------------------
-- Who a unit is, and what role they have
---------------------------------------------------------------------------

local function MyRealm()
	local ok, realm = pcall(GetNormalizedRealmName)
	realm = ok and Readable(realm) or nil
	return (type(realm) == "string" and realm ~= "") and realm or nil
end

--- "Name-Realm" for a player, or nil.
function ns.Key(name, realm)
	name, realm = Readable(name), Readable(realm)
	if type(name) ~= "string" or name == "" then return nil end
	if name:find("-", 1, true) then return name end
	if type(realm) ~= "string" or realm == "" then realm = MyRealm() end
	return realm and (name .. "-" .. realm:gsub("%s", "")) or name
end

function ns.IsPlayer(unit)
	local ok, isPlayer = pcall(UnitIsPlayer, unit)
	return ok and Readable(isPlayer) == true
end

function ns.UnitKey(unit)
	if not unit or not ns.IsPlayer(unit) then return nil end
	local ok, name, realm = pcall(UnitName, unit)
	if not ok then return nil end
	return ns.Key(name, realm)
end

--- The role to show for a unit and where it came from ("mark" or "group").
function ns.RoleFor(unit)
	if not ns.db then return nil end
	local key = ns.UnitKey(unit)
	if not key then return nil end
	local mark = ns.db.marks[key]
	if mark == "NONE" then return nil end
	if mark then return mark, "mark" end
	local ok, role = pcall(UnitGroupRolesAssigned, unit)
	role = ok and Readable(role) or nil
	if role and ns.COORDS[role] and ns.db.auto[role] then return role, "group" end
	return nil
end

---------------------------------------------------------------------------
-- Marking
---------------------------------------------------------------------------

ns.listeners = {}
function ns.Changed()
	for _, fn in ipairs(ns.listeners) do pcall(fn) end
end

--- role: TANK / HEALER / DAMAGER, "NONE" (no icon at all), or nil (back to
--- the group's role).
function ns.SetMark(key, role, quiet)
	if not key or not ns.db then return end
	if ns.db.marks[key] == role then return end
	ns.db.marks[key] = role
	ns.Changed()
	if not quiet then ns.SendMark(key, role) end
end

---------------------------------------------------------------------------
-- Sharing with the group (other Forever Roles users only)
---------------------------------------------------------------------------

local PREFIX = "FRoles"
local registered = false

local function Channel()
	if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
end

local function Send(text)
	if not ns.db or not ns.db.share or not registered then return end
	local channel = Channel()
	if not channel or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
	-- Can be refused (in combat, during an encounter, or rate limited); the
	-- next roster change or request resends what matters.
	pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel)
end

function ns.SendMark(key, role)
	Send("S|" .. key .. "|" .. (role or "-"))
end

--- Everyone's marks for players currently in the group, in messages of up
--- to 240 characters.
local function GroupMembers()
	local units, members = {}, {}
	if IsInRaid and IsInRaid() then
		for i = 1, 40 do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, 4 do units[#units + 1] = "party" .. i end
	end
	for _, unit in ipairs(units) do
		local ok, exists = pcall(UnitExists, unit)
		if ok and Readable(exists) then
			local key = ns.UnitKey(unit)
			if key then members[key] = unit end
		end
	end
	return members
end
ns.GroupMembers = GroupMembers

local function SendAll()
	local parts = {}
	for key in pairs(GroupMembers()) do
		local role = ns.db.marks[key]
		if role then parts[#parts + 1] = key .. "=" .. role end
	end
	local line = ""
	for _, part in ipairs(parts) do
		if #line + #part + 1 > 240 then Send("A|" .. line); line = "" end
		line = (line == "" and "" or line .. ";") .. part
	end
	if line ~= "" then Send("A|" .. line) end
end

local VALID = { TANK = true, HEALER = true, DAMAGER = true, NONE = true }

local function Receive(text, sender)
	local kind, rest = text:match("^(%a)|(.*)$")
	if kind == "S" then
		local key, role = rest:match("^([^|]+)|(.+)$")
		if key then ns.SetMark(key, VALID[role] and role or nil, true) end
	elseif kind == "A" then
		for key, role in rest:gmatch("([^;=]+)=([%u]+)") do
			if VALID[role] then ns.SetMark(key, role, true) end
		end
	elseif kind == "Q" then
		SendAll()
	end
end

---------------------------------------------------------------------------
-- Right-click menus
---------------------------------------------------------------------------

local MENUS = { "SELF", "PARTY", "PLAYER", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "FRIEND", "ENEMY_PLAYER" }

local function KeyFromContext(contextData)
	if type(contextData) ~= "table" then return nil end
	local unit = contextData.unit
	if unit then
		local ok, exists = pcall(UnitExists, unit)
		if ok and Readable(exists) then return ns.UnitKey(unit) end
	end
	return ns.Key(contextData.name, contextData.server)
end

local function AddMenu(owner, rootDescription, contextData)
	local key = KeyFromContext(contextData)
	if not key then return end -- not a player, or a name we cannot read
	rootDescription:CreateDivider()
	local sub = rootDescription:CreateButton("Mark as")
	for _, role in ipairs(ns.ORDER) do
		sub:CreateRadio(ns.IconString(role) .. " " .. ns.LABEL[role],
			function() return ns.db.marks[key] == role end,
			function() ns.SetMark(key, role) end)
	end
	sub:CreateDivider()
	sub:CreateRadio("No icon", function() return ns.db.marks[key] == "NONE" end,
		function() ns.SetMark(key, "NONE") end)
	sub:CreateButton("Use group role", function() ns.SetMark(key, nil) end)
end

local function HookMenus()
	if not Menu or not Menu.ModifyMenu then
		ns.Print("this client has no menu API: marking by right-click is unavailable, use /froles mark <tank|healer|dps|none|clear>")
		return
	end
	for _, which in ipairs(MENUS) do
		pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, AddMenu)
	end
end

---------------------------------------------------------------------------
-- Events and slash command
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= ADDON then return end
		InitDB()
		HookMenus()
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			registered = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
		end
		self:UnregisterEvent("ADDON_LOADED")
		for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD" }) do
			self:RegisterEvent(e)
		end
		if ns.OnLoad then ns.OnLoad() end
		return
	end
	if event == "CHAT_MSG_ADDON" then
		local prefix, text, _, sender = ...
		if Readable(prefix) ~= PREFIX or type(Readable(text)) ~= "string" then return end
		sender = Readable(sender)
		local me = ns.UnitKey("player")
		if sender and me and ns.Key(sender) == me then return end -- our own message
		Receive(text, sender)
		return
	end
	if event == "GROUP_ROSTER_UPDATE" then
		-- Someone joined: ask for the group's marks (answered by every user).
		local count = GetNumGroupMembers and GetNumGroupMembers() or 0
		if count ~= ns.lastCount then
			if (ns.lastCount or 0) < count then Send("Q|") end
			ns.lastCount = count
		end
	end
	ns.Changed()
end)

SLASH_FOREVERROLES1 = "/froles"
SLASH_FOREVERROLES2 = "/foreverroles"
SlashCmdList.FOREVERROLES = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	local cmd, arg = msg:match("^(%S*)%s*(.-)$")
	if cmd == "" or cmd == "options" or cmd == "settings" then
		if ns.OpenOptions then ns.OpenOptions() end
	elseif cmd == "mark" then
		local key = ns.UnitKey("target")
		local map = { tank = "TANK", healer = "HEALER", heal = "HEALER", dps = "DAMAGER", damage = "DAMAGER", none = "NONE" }
		if not key then ns.Print("target a player first"); return end
		if arg == "clear" then ns.SetMark(key, nil) ns.Print("cleared the mark on " .. key)
		elseif map[arg] then ns.SetMark(key, map[arg]) ns.Print("marked " .. key .. " as " .. (ns.LABEL[map[arg]] or "no icon"))
		else ns.Print("/froles mark tank | healer | dps | none | clear  (on your target)") end
	elseif cmd == "list" then
		local any = false
		for key, unit in pairs(GroupMembers()) do
			local role, from = ns.RoleFor(unit)
			if role then any = true; ns.Print(ns.IconString(role) .. " " .. key .. " (" .. (from == "mark" and "marked" or "group role") .. ")") end
		end
		if not any then ns.Print("nobody in your group has a role icon") end
	elseif cmd == "clear" then
		wipe(ns.db.marks); ns.Changed(); ns.Print("all marks cleared (group roles still show where auto-marking is on)")
	elseif cmd == "sync" then
		SendAll(); Send("Q|"); ns.Print("sent your marks and asked the group for theirs")
	else
		ns.Print("/froles (settings), /froles mark <tank|healer|dps|none|clear>, /froles list, /froles clear, /froles sync")
	end
end
