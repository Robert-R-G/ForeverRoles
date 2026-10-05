--[[
	Forever Roles - the settings page (Options > AddOns > Forever Roles, or /froles).
]]

local _, ns = ...

local panel = CreateFrame("Frame")
panel.name = "Forever Roles"
local category

local function Check(label, tooltip, get, set, y, x)
	local box = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	box:SetPoint("TOPLEFT", x or 16, y)
	local text = box.Text
	if type(text) ~= "table" then
		text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
		text:SetPoint("LEFT", box, "RIGHT", 2, 0)
	end
	text:SetText(label)
	box.tooltipText = tooltip
	box:SetScript("OnShow", function(self) self:SetChecked(ns.db and get() or false) end)
	box:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		ns.Changed()
	end)
	box:SetScript("OnEnter", function(self)
		if not tooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(label, 1, 1, 1)
		GameTooltip:AddLine(tooltip, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return box
end

local function Heading(text, y)
	local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	h:SetPoint("TOPLEFT", 16, y)
	h:SetText(text)
end

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Forever Roles")
local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
sub:SetWidth(560)
sub:SetJustifyH("LEFT")
sub:SetText("Right-click a player and choose Mark as to give them a tank, healer or DPS icon. "
	.. "Your marks win over the group's roles; \"No icon\" hides one player's icon entirely.")

Heading("Auto-mark from group roles", -72)
local y = -94
for _, role in ipairs(ns.ORDER) do
	Check(ns.IconString(role, 16) .. " " .. ns.LABEL[role] .. "s",
		"Show the " .. ns.LABEL[role]:lower() .. " icon on players the group assigned the "
			.. ns.LABEL[role]:lower() .. " role (Group Finder or role check), unless you marked them yourself.",
		function() return ns.db.auto[role] end, function(v) ns.db.auto[role] = v end, y)
	y = y - 28
end

Heading("Show icons on", y - 10)
y = y - 32
for _, place in ipairs({
	{ "target", "Target and focus frames", "Above the portrait of your target and focus." },
	{ "nameplates", "Nameplates", "Left of the name. Friendly nameplates inside dungeons are off-limits to addons." },
	{ "group", "Party and raid frames", "On the party frames and the raid-style group frames." },
	{ "tooltip", "Tooltip", "A line under the player's name when you mouse over them." },
}) do
	local key = place[1]
	Check(place[2], place[3], function() return ns.db.show[key] end, function(v) ns.db.show[key] = v end, y)
	y = y - 28
end

Heading("Group", y - 10)
y = y - 32
Check("Share my marks with the group",
	"Groupmates who also run Forever Roles see your marks, and you see theirs. Sent through the hidden addon channel; nothing appears in chat.",
	function() return ns.db.share end, function(v) ns.db.share = v end, y)

if Settings and Settings.RegisterCanvasLayoutCategory then
	category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
	InterfaceOptions_AddCategory(panel)
end

function ns.OpenOptions()
	if category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end
