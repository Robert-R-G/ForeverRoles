--[[
	Forever Roles - where the icons show.

	Every icon is a frame of our own anchored to Blizzard's frame; nothing is
	written into Blizzard's frames, so nothing they do is tainted. Which frame
	an icon belongs to is kept in this file's own tables.

	  target / focus   above the portrait
	  nameplates       above the name (friendly nameplates inside instances
	                   are off-limits to addons, so none show there)
	  group frames     the raid-style party and raid frames (top-right corner)
	                   and the classic party frames (above the portrait)
	  tooltip          a line under the player's name
]]

local _, ns = ...

local function NewIcon(size)
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetSize(size, size)
	f:SetFrameStrata("MEDIUM")
	f.tex = f:CreateTexture(nil, "OVERLAY")
	f.tex:SetAllPoints()
	f.tex:SetTexture(ns.ICON_FILE)
	f:Hide()
	return f
end

local function Apply(icon, role)
	if role and ns.COORDS[role] then
		icon.tex:SetTexCoord(unpack(ns.COORDS[role]))
		icon:Show()
	else
		icon:Hide()
	end
end

local function Visible(frame)
	if not frame then return false end
	local okF, forbidden = pcall(frame.IsForbidden, frame)
	if okF and forbidden then return false end
	local ok, shown = pcall(frame.IsVisible, frame)
	return ok and ns.Readable(shown) == true
end

---------------------------------------------------------------------------
-- Target and focus frames
---------------------------------------------------------------------------

local unitIcons = {}

local function Region(v)
	return type(v) == "table" and type(v.GetObjectType) ~= "nil" and v or nil
end

local function Portrait(frame)
	local container = Region(frame.TargetFrameContainer)
	local named = type(frame.GetName) == "function" and frame:GetName()
	return (container and Region(container.Portrait)) or Region(frame.portrait)
		or (type(named) == "string" and Region(_G[named .. "Portrait"])) or frame
end

local function UpdateUnitFrame(unit, frame)
	local icon = unitIcons[unit]
	if not frame then return end
	if not icon then
		icon = NewIcon(26)
		icon:SetPoint("BOTTOM", Portrait(frame), "TOP", 0, -4)
		icon:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
		unitIcons[unit] = icon
	end
	local role = ns.db.show.target and Visible(frame) and ns.RoleFor(unit) or nil
	Apply(icon, role)
end

local function UpdateTargets()
	UpdateUnitFrame("target", _G.TargetFrame)
	UpdateUnitFrame("focus", _G.FocusFrame)
end

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

local plateIcons = setmetatable({}, { __mode = "k" }) -- nameplate -> icon

local function PlateIcon(plate)
	local icon = plateIcons[plate]
	if icon then return icon end
	icon = NewIcon(18)
	icon:SetParent(plate)
	local uf = plate.UnitFrame
	local anchor = uf and (uf.name or uf.HealthBarsContainer) or plate
	-- Centred just above the name, where it reads at a glance.
	icon:SetPoint("BOTTOM", anchor, "TOP", 0, 2)
	plateIcons[plate] = icon
	return icon
end

local function UpdatePlate(unit)
	if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
	local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit) -- nil for off-limits plates
	if not ok or not plate then return end
	local role = ns.db.show.nameplates and ns.RoleFor(unit) or nil
	if not role and not plateIcons[plate] then return end
	Apply(PlateIcon(plate), role)
end

local function UpdatePlates()
	if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
	for _, plate in pairs(C_NamePlate.GetNamePlates()) do
		local uf = plate.UnitFrame
		local unit = uf and ns.Readable(uf.unit)
		if unit then UpdatePlate(unit)
		elseif plateIcons[plate] then plateIcons[plate]:Hide() end
	end
end

---------------------------------------------------------------------------
-- Group frames
---------------------------------------------------------------------------

local compactIcons = setmetatable({}, { __mode = "k" }) -- CompactUnitFrame -> icon

local function UpdateCompact(frame)
	if not frame or (frame.IsForbidden and frame:IsForbidden()) then return end
	local unit = ns.Readable(frame.unit)
	local role = unit and ns.db.show.group and ns.RoleFor(unit) or nil
	local icon = compactIcons[frame]
	if not icon then
		if not role then return end
		icon = NewIcon(14)
		icon:SetParent(frame)
		icon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
		icon:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
		compactIcons[frame] = icon
	end
	Apply(icon, role)
end

local partyIcons = {}

local function UpdateParty()
	local party = _G.PartyFrame
	for i = 1, 4 do
		local frame = party and party["MemberFrame" .. i] or _G["PartyMemberFrame" .. i]
		if frame then
			local icon = partyIcons[i]
			if not icon then
				icon = NewIcon(20)
				icon:SetPoint("BOTTOM", frame.Portrait or frame.portrait or frame, "TOP", 0, -4)
				icon:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
				partyIcons[i] = icon
			end
			local unit = ns.Readable(frame.unit) or ("party" .. i)
			Apply(icon, ns.db.show.group and Visible(frame) and ns.RoleFor(unit) or nil)
		end
	end
end

local function UpdateCompactAll()
	for frame in pairs(compactIcons) do UpdateCompact(frame) end
	-- Frames that have not been seen yet are picked up by the hook below.
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------

local function TooltipLine(tooltip)
	if not ns.db or not ns.db.show.tooltip or tooltip ~= GameTooltip then return end
	local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
	unit = ok and ns.Readable(unit) or nil
	if not unit then return end
	local role, from = ns.RoleFor(unit)
	if not role then return end
	tooltip:AddLine(ns.IconString(role, 14) .. " " .. ns.LABEL[role]
		.. (from == "group" and "  |cff9d9d9d(group role)|r" or ""), 1, 0.82, 0)
end

---------------------------------------------------------------------------
-- Wiring
---------------------------------------------------------------------------

local function RefreshAll()
	if not ns.db then return end
	UpdateTargets()
	UpdatePlates()
	UpdateCompactAll()
	UpdateParty()
end
table.insert(ns.listeners, RefreshAll)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
	if not ns.db then return end
	if event == "NAME_PLATE_UNIT_ADDED" then
		UpdatePlate(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
		if ok and plate and plateIcons[plate] then plateIcons[plate]:Hide() end
	elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
		UpdateTargets()
	else
		RefreshAll()
	end
end)

function ns.OnLoad()
	for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
		"PLAYER_FOCUS_CHANGED", "UNIT_NAME_UPDATE" }) do
		pcall(events.RegisterEvent, events, e)
	end
	-- Raid-style frames: every time Blizzard assigns or refreshes one.
	for _, fn in ipairs({ "CompactUnitFrame_SetUnit", "CompactUnitFrame_UpdateAll" }) do
		if type(_G[fn]) == "function" then hooksecurefunc(fn, function(frame) pcall(UpdateCompact, frame) end) end
	end
	if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip) pcall(TooltipLine, tooltip) end)
	elseif GameTooltip then
		GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip) pcall(TooltipLine, tooltip) end)
	end
	RefreshAll()
end
