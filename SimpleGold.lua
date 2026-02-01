-- SimpleGold.lua
-- =========================
-- Minimal gold tracker with per-realm totals and a compact display.

-- Globals:
-- =========================
SimpleGold_variablesLoaded = false
SimpleGold_firstRun = true
SimpleGold_UpdateInterval = 5 -- shouldn't need to update often
SimpleGold_UpdateTimer = 0

-- Locals:
-- =========================
local myPlayerRealm = GetRealmName()
local myPlayerName = UnitName("player")
local myPlayerID = (myPlayerName or "Unknown") .. "**" .. (myPlayerRealm or "Unknown")
local myPlayerClassText, myPlayerClassType = UnitClass("player")

local lastWindowState = false

-- Preset color options:
local colorPresetList = {
	{ 1,  1,  1,  0 },
	{ 0,  0,  0,  1 },
	{ 0,  0,  0,  .6 },
	{ .5, .5, .5, .6 },

	{ .5, 0,  0,  .6 },
	{ .5, 0,  0,  1 },
	{ 1,  0,  0,  1 },

	{ 0,  .5, 0,  .6 },
	{ 0,  .5, 0,  1 },
	{ 0,  1,  0,  1 },

	{ 0,  0,  .5, .6 },
	{ .5, 0,  .5, 1 },
	{ 0,  0,  1,  1 },

	{ .5, .5, 0,  .6 },
	{ .5, .5, 0,  1 },
	{ 1,  1,  0,  1 },

	{ .5, 0,  .5, .6 },
	{ .5, 0,  .5, 1 },
	{ 1,  0,  1,  1 },

	{ 0,  .5, .5, .6 },
	{ 0,  .5, .5, 1 },
	{ 0,  1,  1,  1 },
}

-- Previous client build (for version-aware changes if needed)
local prevVersion = 1
if SimpleGoldSavedVars ~= nil and SimpleGoldSavedVars.clientBuild ~= nil then
	prevVersion = SimpleGoldSavedVars.clientBuild
end

-- Saved variables initialization
-- =========================
local function FixVars()
	local _, _, _, tocversion = GetBuildInfo()

	if SimpleGoldSavedVars == nil then
		SimpleGoldSavedVars = {
			xPos = 0,
			yPos = 0,
			lastPreset = 1,
			color = { 0, 0, 0, 1 },
			borderStyle = 1,
			viz = true,
			locked = false,
			clientBuild = tocversion,
		}
	end

	-- Ensure required keys exist
	if SimpleGoldSavedVars.viz == nil then
		SimpleGoldSavedVars.viz = true
	end
	if SimpleGoldSavedVars.locked == nil then
		SimpleGoldSavedVars.locked = false
	end
	if SimpleGoldSavedVars.clientBuild == nil then
		SimpleGoldSavedVars.clientBuild = tocversion
	end

	-- Clamp preset index
	if type(SimpleGoldSavedVars.lastPreset) ~= "number" or SimpleGoldSavedVars.lastPreset < 1 or SimpleGoldSavedVars.lastPreset > #colorPresetList then
		SimpleGoldSavedVars.lastPreset = 1
	end
	-- Validate color table
	if type(SimpleGoldSavedVars.color) ~= "table" or #SimpleGoldSavedVars.color < 4 then
		SimpleGoldSavedVars.color = { 0, 0, 0, 1 }
	end
end

-- Utils
-- =========================
local function SimpleGold_FormatNumber(amount)
	local locale = GetLocale()
	local sep = ","
	if locale == "deDE" or locale == "frFR" or locale == "esES" or locale == "itIT" then
		sep = "."
	end
	local str = tostring(amount)
	while true do
		local newStr, k = str:gsub("^(-?%d+)(%d%d%d)", "%1" .. sep .. "%2")
		str = newStr
		if k == 0 then break end
	end
	return str
end

local function SimpleGold_NormalizeString(s)
	-- makes a string lower case and trims whitespace
	s = string.lower(s or "")
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- Data/state updates
-- =========================
local function DrawBG()
	FixVars()
	local tColor = SimpleGoldSavedVars.color
	if SimpleGold_BackgroundTexture and tColor then
		SimpleGold_BackgroundTexture:SetVertexColor(tColor[1], tColor[2], tColor[3], tColor[4])
	end
end

local function UpdateGlobalGold()
	if SimpleGoldGlobals == nil then
		SimpleGoldGlobals = {}
	end
	if myPlayerRealm == nil then
		myPlayerRealm = GetRealmName()
	end
	if myPlayerName == nil then
		myPlayerName = UnitName("player")
	end
	if myPlayerRealm == nil or myPlayerName == nil then
		return
	end
	if SimpleGoldGlobals[myPlayerRealm] == nil then
		SimpleGoldGlobals[myPlayerRealm] = {}
	end
	SimpleGoldGlobals[myPlayerRealm][myPlayerName] = GetMoney()
end

function SimpleGoldUpdate()
	-- Toggle visibility only if state changed
	if lastWindowState ~= SimpleGoldSavedVars.viz then
		lastWindowState = SimpleGoldSavedVars.viz
		if lastWindowState then
			if SimpleGoldDisplayFrame then SimpleGoldDisplayFrame:Show() end
		else
			if SimpleGoldDisplayFrame then SimpleGoldDisplayFrame:Hide() end
		end
	end

	local money = GetMoney()
	UpdateGlobalGold()
	if MoneyFrame_Update then
		MoneyFrame_Update("SimpleGoldMoney", money)
	end
	DrawBG()
end

function SimpleGoldServiceUpdate(elapsed)
	SimpleGold_UpdateTimer = SimpleGold_UpdateTimer + (elapsed or 0)
	if SimpleGold_UpdateTimer > SimpleGold_UpdateInterval then
		SimpleGoldUpdate()
		SimpleGold_UpdateTimer = 0
	end
end

-- Tooltip
-- =========================
function SimpleGold_ShowTooltip()
	local totalGold = 0
	if not SimpleGoldDisplayFrame then return end

	GameTooltip:SetOwner(SimpleGoldDisplayFrame, "ANCHOR_CURSOR", -5, 5)

	if not SimpleGoldGlobals or not myPlayerRealm or not SimpleGoldGlobals[myPlayerRealm] then
		GameTooltip:AddLine("Gold Data Unavailable", 1, 0.2, 0.2)
		GameTooltip:Show()
		return
	end

	local thisRealmList = SimpleGoldGlobals[myPlayerRealm]
	local sortedChars = {}

	for charName, gold in pairs(thisRealmList) do
		totalGold = totalGold + (gold or 0)
		table.insert(sortedChars, { name = charName, gold = gold or 0 })
	end

	table.sort(sortedChars, function(a, b)
		if a.gold == b.gold then
			return a.name < b.name
		end
		return a.gold > b.gold
	end)

	local totalGoldFormatted = SimpleGold_FormatNumber(math.floor(totalGold / 10000))
	GameTooltip:AddDoubleLine("Total", totalGoldFormatted .. "g", 0.8, 0.8, 1, 1, 1, 1)
	GameTooltip:AddLine(" ")

	for _, entry in ipairs(sortedChars) do
		local goldFormatted = SimpleGold_FormatNumber(math.floor(entry.gold / 10000))
		GameTooltip:AddDoubleLine(entry.name, goldFormatted .. "g", 0.8, 0.8, 0.8, 1, 1, 1, 1)
		-- Right align the right text
		local line = GameTooltip:NumLines()
		local rightText = _G["GameTooltipTextRight" .. line]
		if rightText then
			rightText:SetJustifyH("RIGHT")
		end
	end

	GameTooltip:Show()
end

function SimpleGold_HideTooltip()
	GameTooltip:Hide()
end

-- Frame/position helpers
-- =========================
function SimpleGoldPrefsCenter()
	SimpleGoldSavedVars.xPos = 0
	SimpleGoldSavedVars.yPos = 0
	if not SimpleGoldDisplayFrame then return end
	SimpleGoldDisplayFrame:ClearAllPoints()
	SimpleGoldDisplayFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0)
end

function SimpleGoldSaveLastPosition()
	if not SimpleGoldDisplayFrame then return end
	local point, _, _, xOff, yOff = SimpleGoldDisplayFrame:GetPoint()
	SimpleGoldSavedVars.xPos = xOff or 0
	SimpleGoldSavedVars.yPos = yOff or 0
end

-- Color preset cycle
function SimpleGold_StepBackground()
	FixVars()
	local currentStep = (SimpleGoldSavedVars.lastPreset or 1)
	local presetCount = #colorPresetList
	currentStep = currentStep + 1
	if currentStep > presetCount then
		currentStep = 1
	end
	local tColor = colorPresetList[currentStep]
	if SimpleGold_BackgroundTexture and tColor then
		SimpleGold_BackgroundTexture:SetVertexColor(tColor[1], tColor[2], tColor[3], tColor[4])
	end
	SimpleGoldSavedVars.lastPreset = currentStep
	SimpleGoldSavedVars.color = tColor
end

-- Events
-- =========================
function SimpleGold_OnLoad(self)
	-- Slash command
	SLASH_SimpleGold1 = "/simplegold"
	SlashCmdList["SimpleGold"] = SimpleGold_CommandLine

	-- Events
	self:RegisterEvent("VARIABLES_LOADED")
	self:RegisterEvent("PLAYER_MONEY")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- Ensure names
	if not myPlayerName then
		myPlayerName = UnitName("player")
		myPlayerID = myPlayerName .. "**" .. (myPlayerRealm or "Unknown")
	end

	-- Welcome message
	if DEFAULT_CHAT_FRAME and SGOLDTEXT and SGOLDTEXT.WELCOME then
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.WELCOME, 0.5, 1.0, 0.5, 1)
	end

	UpdateGlobalGold()
end

function SimpleGold_Event(self, event, ...)
	if event == "VARIABLES_LOADED" then
		SimpleGold_variablesLoaded = true
		FixVars()
		-- Force initial draw by toggling
		lastWindowState = not SimpleGoldSavedVars.viz
		return
	end

	if event == "PLAYER_MONEY" then
		SimpleGoldUpdate()
		return
	end

	if event == "PLAYER_ENTERING_WORLD" then
		-- Refresh and ensure the frame visibility matches saved state
		SimpleGoldUpdate()
		return
	end
end

-- Slash commands
-- =========================
function SimpleGold_CommandLine(msg)
	local cmd = string.lower(msg or "")

	-- Help
	if msg == "" or cmd == "help" then
		local p = "/simplegold "
		if DEFAULT_CHAT_FRAME then
			if SASSTEXT_TITLE then DEFAULT_CHAT_FRAME:AddMessage(SASSTEXT_TITLE, 0.5, 1.0, 0.5, 1) end
			if SGOLDTEXT and SGOLDTEXT.HELP then DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.HELP, 0.8, 0.8, 0.8, 1) end
			if SGOLDTEXT then
				DEFAULT_CHAT_FRAME:AddMessage(p .. SGOLDTEXT.SHOW .. " - " .. SGOLDTEXT.SHOW_DESCRIPTION, 0.8, 0.8, 0.8,
					1)
				DEFAULT_CHAT_FRAME:AddMessage(p .. SGOLDTEXT.HIDE .. " - " .. SGOLDTEXT.HIDE_DESCRIPTION, 0.8, 0.8, 0.8,
					1)
				DEFAULT_CHAT_FRAME:AddMessage(p .. SGOLDTEXT.LOCK .. " - " .. SGOLDTEXT.LOCK_DESCRIPTION, 0.8, 0.8, 0.8,
					1)
				DEFAULT_CHAT_FRAME:AddMessage(p .. SGOLDTEXT.UNLOCK .. " - " .. SGOLDTEXT.UNLOCK_DESCRIPTION, 0.8, 0.8,
					0.8, 1)
				DEFAULT_CHAT_FRAME:AddMessage(p .. SGOLDTEXT.CENTER .. " - " .. SGOLDTEXT.CENTER_DESCRIPTION, 0.8, 0.8,
					0.8, 1)
				DEFAULT_CHAT_FRAME:AddMessage(
					p .. SGOLDTEXT.DELETE .. " {character name} - " .. SGOLDTEXT.DELETE_DESCRIPTION, 0.8, 0.8, 0.8, 1)
			end
		end
		-- do not return; allow further parsing (e.g., delete)
	end

	-- Delete
	local delStart, delEnd = string.find(cmd, "delete ", 1, true)
	if delStart then
		local tName = string.sub(msg, delEnd + 1)
		local normalizedName = SimpleGold_NormalizeString(tName)
		if SimpleGoldGlobals and myPlayerRealm and strlenutf8(normalizedName) > 0 then
			local tList = SimpleGoldGlobals[myPlayerRealm]
			if type(tList) == "table" then
				local foundIndex = nil
				for k, _ in pairs(tList) do
					if SimpleGold_NormalizeString(k) == normalizedName then
						foundIndex = k
						break
					end
				end

				local oStr
				if foundIndex ~= nil then
					SimpleGoldGlobals[myPlayerRealm][foundIndex] = nil
					oStr = (SGOLDTEXT and SGOLDTEXT.CONFIRM_DELETE) and
						(string.gsub(SGOLDTEXT.CONFIRM_DELETE, "_CHARNAME_", tName)) or ("Removed: " .. tName)
				else
					oStr = (SGOLDTEXT and SGOLDTEXT.NOTOON) and (string.gsub(SGOLDTEXT.NOTOON, "_CHARNAME_", tName)) or
						("No character: " .. tName)
				end
				if DEFAULT_CHAT_FRAME then
					DEFAULT_CHAT_FRAME:AddMessage(oStr, 0.8, 0.8, 0.8, 1)
				end
			end
		end
	end

	-- Simple toggles/commands
	if SGOLDTEXT and cmd == SGOLDTEXT.SHOW then
		if SimpleGoldDisplayFrame then SimpleGoldDisplayFrame:Show() end
		if DEFAULT_CHAT_FRAME and SGOLDTEXT.CONFIRM_SHOWING then
			DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_SHOWING, 0.8, 0.8, 0.8, 1)
		end
		return
	end

	if SGOLDTEXT and cmd == SGOLDTEXT.HIDE then
		if SimpleGoldDisplayFrame then SimpleGoldDisplayFrame:Hide() end
		SimpleGoldSavedVars.viz = false
		if DEFAULT_CHAT_FRAME and SGOLDTEXT.CONFIRM_HIDING then
			DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_HIDING, 0.8, 0.8, 0.8, 1)
		end
		return
	end

	if SGOLDTEXT and cmd == SGOLDTEXT.LOCK then
		SimpleGoldSavedVars.locked = true
		if DEFAULT_CHAT_FRAME and SGOLDTEXT.CONFIRM_LOCKED then
			DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_LOCKED, 0.8, 0.8, 0.8, 1)
		end
		return
	end

	if SGOLDTEXT and cmd == SGOLDTEXT.UNLOCK then
		SimpleGoldSavedVars.locked = false
		if DEFAULT_CHAT_FRAME and SGOLDTEXT.CONFIRM_UNLOCKED then
			DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_UNLOCKED, 0.8, 0.8, 0.8, 1)
		end
		return
	end

	if SGOLDTEXT and cmd == SGOLDTEXT.CENTER then
		SimpleGoldSavedVars.locked = false
		SimpleGoldPrefsCenter()
		if DEFAULT_CHAT_FRAME then
			if SGOLDTEXT.CONFIRM_UNLOCKED then
				DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_UNLOCKED, 0.8, 0.8, 0.8, 1)
			end
			if SGOLDTEXT.CONFIRM_CENTER then
				DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_CENTER, 0.8, 0.8, 0.8, 1)
			end
		end
		return
	end
end

-- Prefs frame show/hide
-- =========================
function SimpleGoldPrefsFrameOnShow()
	-- Ensure we have a reasonable position
	if SimpleGoldSavedVars.xPos == nil or SimpleGoldSavedVars.xPos == -6666 then
		SimpleGoldPrefsCenter()
	end

	DrawBG()
	SimpleGoldSavedVars.viz = true
end

function SimpleGoldPrefsFrameOnHide()
	SimpleGoldSavedVars.viz = false
end
