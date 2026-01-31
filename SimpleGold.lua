-- Globals:
-- ========

SimpleGold_variablesLoaded = false;
SimpleGold_firstRun = true;
SimpleGold_UpdateInterval = 5; -- shouldn't need to update often.
SimpleGold_UpdateTimer = 0;

-- Globals

-- Locals:
-- =======



local myPlayerRealm=GetRealmName();
local myPlayerName=UnitName("player");
local myPlayerID=myPlayerName.."**"..myPlayerRealm;
local myPlayerClassText, myPlayerClassType = UnitClass("player");

local lastWindowState = false;

-- preset color options:
local colorPresetList ={
{1,1,1,0}, 
{0,0,0,1},
{0,0,0,.6},
{.5,.5,.5,.6},

{.5,0,0,.6},
{.5,0,0,1},
{1,0,0,1},

{0,.5,0,.6},
{0,.5,0,1},
{0,1,0,1},

{0,0,.5,.6},
{.5,0,.5,1},
{0,0,1,1},

{.5,.5,0,.6},
{.5,.5,0,1},
{1,1,0,1},

{.5,0,.5,.6},
{.5,0,.5,1},
{1,0,1,1},

{0,.5,.5,.6},
{0,.5,.5,1},
{0,1,1,1}

}

-- save last version to detect if client has changed
local prevVersion=1;
if (nil ~= SimpleGoldSavedVars) then
  if (nil ~= SimpleGoldSavedVars["clientBuild"]) then
    prevVersion=SimpleGoldSavedVars["clientBuild"];
  end
end
-- My local functions:
-- ====================

function DrawBG()
-------- ---------------
		FixVars();
		local tColor=SimpleGoldSavedVars["color"];
		SimpleGold_BackgroundTexture:SetVertexColor(tColor[1],tColor[2],tColor[3],tColor[4]);

end


function UpdateGlobalGold()
-------- ---------------
	if (SimpleGoldGlobals == nil) then
		SimpleGoldGlobals = {};
	end
	if (SimpleGoldGlobals[myPlayerRealm]==nil) then
		SimpleGoldGlobals[myPlayerRealm]={};
	end
	SimpleGoldGlobals[myPlayerRealm][myPlayerName]=GetMoney();
end


function FixVars()
-------- ---------------
local version, build, date, tocversion = GetBuildInfo();

-- initialize our saved variables if needed
	if (SimpleGoldSavedVars == nil) then		
		SimpleGoldSavedVars={
			xPos=0,
			yPos=0,
			lastPreset=1,
			color={0,0,0,1},
			borderStyle=1,
			viz=true,
			locked=false,
			clientBuild=tocversion
	};
	end
	if SimpleGoldSavedVars["viz"] == nil then
		SimpleGoldSavedVars["viz"]=true;
	end
	if SimpleGoldSavedVars["locked"] == nil then
		SimpleGoldSavedVars["locked"]=false;
	end
		if SimpleGoldSavedVars["clientBuild"] == nil then
		SimpleGoldSavedVars["clientBuild"]=tocversion;
	end
end



function SimpleGold_OnLoad(self)
	-- Register the slash command
	-- --------------------------
	SLASH_SimpleGold1 = "/simplegold";
	SlashCmdList["SimpleGold"] = SimpleGold_CommandLine;


-- Register the event handlers:
-- =============================	

	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");	
	-- new event: CURRENCY_DISPLAY_UPDATE ?
	if (not myPlayerName) then
		myPlayerName = UnitName("player");
		myPlayerID=myPlayerName.."**"..myPlayerRealm;
	end

	DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.WELCOME,  0.5, 1.0, 0.5, 1);
	UpdateGlobalGold();

end -- OnLoad




	
function SimpleGold_Event(self, event, ...)
	local eventHandled = false;

	-- VARIABLES_LOADED
	-- ================
	if ( event == "VARIABLES_LOADED" ) then	
		-- record that we have been loaded:
		SimpleGold_variablesLoaded = true;
		FixVars();
		lastWindowState= not(SimpleGoldSavedVars["viz"]); -- guarantee initial draw
		eventHandled = true;
	end -- ( event == "VARIABLES_LOADED" )
	
	
	-- Money events:	
	if (eventHandled == false and event == "PLAYER_MONEY") then
		SimpleGoldUpdate(self);
		eventHandled = true;
	end 

	if (eventHandled == false and event == "PLAYER_ENTERING_WORLD") then
		SimpleGoldUpdate(self); -- show the frame if necessary
		eventHandled = true;
	end 
end -- SimpleGold_Event
 


-- command line parameters: (slash command handler)
function SimpleGold_CommandLine(msg)
	local tName;
	local normalizedName;
	local normalizedIndex;
	local foundIndex = nil;
	local oStr, toss;
	
	cmd=string.lower(msg);

	-- display the help mesage:
	if ( msg=="" or cmd=="help") then
		local p="/simplegold ";
		DEFAULT_CHAT_FRAME:AddMessage(SASSTEXT_TITLE,  0.5, 1.0, 0.5, 1);
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.HELP,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.SHOW .. " - " .. SGOLDTEXT.SHOW_DESCRIPTION,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.HIDE .. " - " .. SGOLDTEXT.HIDE_DESCRIPTION,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.LOCK .. " - " .. SGOLDTEXT.LOCK_DESCRIPTION,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.UNLOCK .. " - " .. SGOLDTEXT.UNLOCK_DESCRIPTION,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.CENTER .. " - " .. SGOLDTEXT.CENTER_DESCRIPTION,  0.8, 0.8, 0.8, 1);
		DEFAULT_CHAT_FRAME:AddMessage(p..SGOLDTEXT.DELETE .. " {character name} - " .. SGOLDTEXT.DELETE_DESCRIPTION,  0.8, 0.8, 0.8, 1);
	end

	local delStart, delEnd = string.find(cmd,"delete ",1);
	if (delStart) then
		tName=(string.sub(msg,delEnd+1));
		-- CONFIRM_DELETE="Character &CHARNAME removed from list."
		local tList=SimpleGoldGlobals[myPlayerRealm];
		normalizedName=SimpleGold_NormalizeString(tName);
		if (strlenutf8(normalizedName)>0) then
		
		
			-- look for the name in this realm:
			for k, v in pairs (tList) do
				normalizedIndex=SimpleGold_NormalizeString(k);
				if (normalizedIndex == normalizedName) then
					foundIndex=k
				end
			end -- loop through the names

	
			if (foundIndex ~= nil) then
				SimpleGoldGlobals[myPlayerRealm][foundIndex]=nil;	
				oStr, toss= string.gsub(SGOLDTEXT.CONFIRM_DELETE, "_CHARNAME_", tName);
			else
				oStr, toss= string.gsub(SGOLDTEXT.NOTOON, "_CHARNAME_", tName);
			end
			
			DEFAULT_CHAT_FRAME:AddMessage(oStr,  0.8, 0.8, 0.8, 1);
			
		end -- able to parse a name

	end

	if ( cmd == SGOLDTEXT.SHOW) then
		SimpleGoldDisplayFrame:Show();
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_SHOWING,  0.8, 0.8, 0.8, 1);
	end
		
	if ( cmd == SGOLDTEXT.HIDE) then
		SimpleGoldDisplayFrame:Hide();
		SimpleGoldSavedVars["viz"]=false;
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_HIDING,  0.8, 0.8, 0.8, 1);
	end
	
	if ( cmd == SGOLDTEXT.LOCK) then
		SimpleGoldSavedVars["locked"]=true;
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_LOCKED,  0.8, 0.8, 0.8, 1);
	end
	
	if ( cmd == SGOLDTEXT.UNLOCK) then
		SimpleGoldSavedVars["locked"]=false;
		DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_UNLOCKED,  0.8, 0.8, 0.8, 1);
	end
	
		if ( cmd == SGOLDTEXT.CENTER) then
      SimpleGoldSavedVars["locked"]=false;
      SimpleGoldPrefsCenter()
      DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_UNLOCKED,  0.8, 0.8, 0.8, 1);
      DEFAULT_CHAT_FRAME:AddMessage(SGOLDTEXT.CONFIRM_CENTER,  0.8, 0.8, 0.8, 1);
    end
	
end


function SimpleGoldUpdate(self)
	if (lastWindowState == SimpleGoldSavedVars["viz"]) then
		-- we don't really need to update do we?
	else
		lastWindowState = SimpleGoldSavedVars["viz"];
		if (lastWindowState) then
			SimpleGoldDisplayFrame:Show();
		else
			SimpleGoldDisplayFrame:Hide();
		end
	end
	local money = GetMoney();
	UpdateGlobalGold();
	MoneyFrame_Update("SimpleGoldMoney", money); --"SimpleGoldMoney", money
	DrawBG();

end

function SimpleGoldServiceUpdate(elapsed)
	 
	SimpleGold_UpdateTimer = SimpleGold_UpdateTimer + elapsed; 	
	if (SimpleGold_UpdateTimer > SimpleGold_UpdateInterval) then
	-- DEFAULT_CHAT_FRAME:AddMessage("tick",  0.5, 1.0, 0.5, 1);
		SimpleGoldUpdate();
		SimpleGold_UpdateTimer = 0;
	end

end

-- GUI Handlers:
-- =============================

-- prefs:
-- function SimpleGold_Options_OnClick(arg1)
-- 	id = this:GetID()
-- 	local buttonName=this:GetName()
-- 	SimpleGoldDefaults[buttonName] =getglobal(buttonName):GetChecked();
-- 	SimpleGoldSavedVars[buttonName] =getglobal(buttonName):GetChecked();
-- end



function SimpleGoldPrefsCenter()
-- 
  SimpleGoldSavedVars["xPos"]=0;
  SimpleGoldSavedVars["yPos"]=0;
  SimpleGoldDisplayFrame:ClearAllPoints();
  SimpleGoldDisplayFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0); 


end



-- OnShow
function SimpleGoldPrefsFrameOnShow()
-- see if we need to position this frame:

  if (nil == SimpleGoldSavedVars["xPos"])  then -- No value? Set one
    SimpleGoldPrefsCenter();
    else 
      if (-6666 == SimpleGoldSavedVars["xPos"]) then -- Uninitialized value? Set it
        SimpleGoldPrefsCenter();
      end
  end

	DrawBG();
	SimpleGoldSavedVars["viz"]=true;
	-- SimpleGoldUpdate();
	
end


function SimpleGoldPrefsFrameOnHide()
	SimpleGoldSavedVars["viz"]=false;
end


function SimpleGold_StepBackground()
	FixVars();
	
	local currentStep=SimpleGoldSavedVars["lastPreset"];
	local presetCount=#(colorPresetList);
	currentStep=currentStep+1;
	if (currentStep > presetCount) then
		currentStep=1;
	end
	local tColor=colorPresetList[currentStep];
	SimpleGold_BackgroundTexture:SetVertexColor(tColor[1],tColor[2],tColor[3],tColor[4]);

	SimpleGoldSavedVars["lastPreset"]=currentStep;
	SimpleGoldSavedVars["color"]=tColor;
	-- SimpleGold_BackgroundTexture:SetTexture(1,1,1,0);
	
	-- Frame:SetBackdrop([backdropTable]) - Set the backdrop of the frame according to the specification provided. 
	-- Frame:SetBackdropBorderColor(r,g,b[,a]) - Set the frame's backdrop's border's color. 
	-- Frame:SetBackdropColor(r,g,b[,a]) - Set the frame's backdrop color.
 end
 




local function SimpleGold_FormatNumber(amount)
  local locale = GetLocale()
  local sep = ","

  if locale == "deDE" or locale == "frFR" or locale == "esES" or locale == "itIT" then
    sep = "."
  end

  local str = tostring(amount)
  while true do
    str, k = str:gsub("^(-?%d+)(%d%d%d)", "%1"..sep.."%2")
    if k == 0 then break end
  end
  return str
end  




function SimpleGold_ShowTooltip()
  local totalGold = 0

  GameTooltip:SetOwner(SimpleGoldDisplayFrame, "ANCHOR_CURSOR", -5, 5)

  if not SimpleGoldGlobals or not SimpleGoldGlobals[myPlayerRealm] then
    GameTooltip:AddLine("Gold Data Unavailable", 1, 0.2, 0.2)
    GameTooltip:Show()
    return
  end

  local thisRealmList = SimpleGoldGlobals[myPlayerRealm]
  local sortedChars = {}

  -- Daten sammeln + Gesamtgold
  for charName, gold in pairs(thisRealmList) do
    totalGold = totalGold + gold
    table.insert(sortedChars, {
      name = charName,
      gold = gold
    })
  end

  -- Sortierung:
  -- 1. Mehr Gold zuerst
  -- 2. Bei Gleichstand alphabetisch
  table.sort(sortedChars, function(a, b)
    if a.gold == b.gold then
      return a.name < b.name
    end
    return a.gold > b.gold
  end)

  -- Total anzeigen
  local totalGoldFormatted = SimpleGold_FormatNumber(math.floor(totalGold / 10000))
  GameTooltip:AddDoubleLine(
    "Total",
    totalGoldFormatted .. "g",
    0.8, 0.8, 1,
    1, 1, 1
  )

  GameTooltip:AddLine(" ")

  -- Charaktere anzeigen
  for _, entry in ipairs(sortedChars) do
    local goldFormatted = SimpleGold_FormatNumber(math.floor(entry.gold / 10000))

    GameTooltip:AddDoubleLine(
      entry.name,
      goldFormatted .. "g",
      0.8, 0.8, 0.8,
      1, 1, 1
    )

    -- rechtes Feld rechtsbündig setzen
    local line = GameTooltip:NumLines()
    local rightText = _G["GameTooltipTextRight" .. line]
    if rightText then
      rightText:SetJustifyH("RIGHT")
    end
  end

  GameTooltip:Show()
end


function SimpleGold_HideTooltip()
	GameTooltip:Hide();
end
  

function SimpleGold_NormalizeString(s)
	-- makes a string lower case and trims whitespace
	s=string.lower(s)
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function SimpleGoldSaveLastPosition()
  local point, relativeTo, relativePoint, xOff, yOff;
  point, relativeTo, relativePoint, xOff, yOff = SimpleGoldDisplayFrame:GetPoint();		
  SimpleGoldSavedVars["xPos"]=xOff;
  SimpleGoldSavedVars["yPos"]=yOff;


end
  