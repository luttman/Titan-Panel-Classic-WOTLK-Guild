-- version
TITAN_GUILD_VERSION = "1.0.0.4";
--[[

	Titan Panel [Guild]: A simple guild list for the Titan Panel AddOn.
		copyright 2005 by chicogrande (jluzier@gmail.com)
		copyright 2012 by Kernighan/Yunohu (kernighan@gmail.com)
	- Lists online guild members in a tooltip, green rank text indicating an officer
	- Menu shows names of online members, with click to /whisper functionality. Green text = officer
	- Menu has options to /guild chat and /officer chat
	- Menu has option to toggle Show offline members, which changes this setting in your Social frame, Guild tab
	- Advanced menus to /w, /invite, /friend or /who guild members
	- Shows default messages if the player is not a member of a guild
	- Updates the guild listing every 5 minutes to accomodate the GuildRoster() delay. The update only takes place if
	  the player is 'idle' and not accessing conflicting UI frames or Titan elements
	- Tooltip and right-click menu content is sortable using the Sort menu option, works like the guild frame
	- Colors rank names (Advanced) or player names (Simple) based on rank index
	- To save space, player can turn off menu options
	- Filtering on a level range and zone, as it relates to the player
	- Filtering on a single class in the player's faction
	- Paging of simple and advanced right-click menu contents to deal with large-guild issues
]]

----------------------------------------------------------------------
--  Local variables
----------------------------------------------------------------------

TITAN_GUILD_ID = "Guild";
TITAN_NIL = false;
GUILD_THIS = {};

-- attempting to update every 300 seconds
TITAN_GUILD_FREQUENCY = 300;
-- the guild tab #
TITAN_GUILD_TAB_NUMBER = 3;
-- function used to hide options
TITAN_GUILD_BUTTON_SHOWOPTIONS = "TitanPanelGuildButton_ToggleShowMenuOptions";
TITAN_GUILD_BUTTON_CLOSEMENU = "TitanPanelGuildButton_CloseMenu";
TITAN_GUILD_BUTTON_COMPUTEPAGES = "TitanPanelGuildButton_ComputePages";
TITAN_GUILD_BUTTON_FORWARDPAGE = "TitanPanelGuildButton_PageForward";
TITAN_GUILD_BUTTON_BACKWARDPAGE = "TitanPanelGuildButton_PageBackward";

-- threshold for leaf level items in right-click menu
TITAN_GUILD_LIST_THRESHOLD = 15;
TITAN_GUILD_TOOLTIP_THRESHOLD = 30;

-- my internal timer used to keep track of when to run GuildRoster()
guild_TimeCounter = 0;
-- tables used to build the rank based right-click messaging menu
masterTable = {};
masterTableSimple = {};
-- level range for filtering on level +/- TITAN_GUILD_LEVEL_RANGE
TITAN_GUILD_LEVEL_RANGE = 5;
-- for MoP
TITAN_GUILD_LEVEL_MAX_CAP = MAX_PLAYER_LEVEL;

-- paging vars
currIndex = 1;
maxIndex = TITAN_GUILD_LIST_THRESHOLD;
numGuildOnline = 0;
numGuildOnlineFiltered = 0;
numPages = 0;
currPage = 1;
pagingRemainder = 0;
priorAdvMenuValue = TITAN_NIL;
TitanGuildFirstCycle = true;

----------------------------------------------------------------------
--  TitanPanelGuildButton_OnLoad()
----------------------------------------------------------------------
function TitanPanelGuildButton_OnLoad(self)
	-- if( DEFAULT_CHAT_FRAME ) then
	-- 	DEFAULT_CHAT_FRAME:AddMessage("Titan Panel [Guild] v"..TITAN_GUILD_VERSION.." loaded");
	-- end

	-- init guild_TimeCounter
	guild_TimeCounter = 0;
	masterTable = {};
	masterTableSimple = {};
	--TitanPanelGuildButton_ListInitMaster();
	self.registry = {
		id = TITAN_GUILD_ID,
		version = TITAN_GUILD_VERSION,
		menuText = TITAN_GUILD_MENU_TEXT,
		buttonTextFunction = "TitanPanelGuildButton_GetButtonText",
		tooltipTitle = TITAN_GUILD_TOOLTIP,
		tooltipTextFunction = "TitanPanelGuildButton_GetTooltipText",
		icon = "Interface\\PetitionFrame\\GuildCharter-Icon.blp",
		iconWidth = 16,
		savedVariables = {
			ShowLabelText = 1,
			ShowIcon = 1,
			ShowAdvancedMenus = 0,
			ShowMenuOptions = 1,
			ShowTooltipName = 1,
			ShowTooltipZone = 1,
			ShowTooltipRank = 1,
			ShowTooltipNote = TITAN_NIL,
			ShowTooltipLevel = 1,
			ShowTooltipClass = 1,
			TooltipSize = 30,
			FilterMyLevel = TITAN_NIL,
			FilterMyZone = TITAN_NIL,
			FilterClasses = TITAN_NIL,
			SortByValue = TITAN_NIL,
			DisableRosterUpdates = TITAN_NIL,
			DisableMouseOverUpdates = 1,
			RosterUpdateTime = TITAN_GUILD_FREQUENCY,
		}
	};
	self:RegisterEvent("GUILD_ROSTER_UPDATE");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("GUILD_REGISTRAR_SHOW");
	self:RegisterEvent("GUILD_REGISTRAR_CLOSED");
	
	GUILD_THIS = self;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OnEvent(self)
--  traps and deals with GUILD_ROSTER_UPDATE
----------------------------------------------------------------------
function TitanPanelGuildButton_OnEvent(self)
	if (event == "PLAYER_ENTERING_WORLD") then
		--guildPrintDebugMessage(event);
		if (IsInGuild()) then
			FriendsFrame:UnregisterEvent("GUILD_ROSTER_UPDATE");
			GuildRoster();
			FriendsFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
		end
	elseif (event == "GUILD_ROSTER_UPDATE") then
		--guildPrintDebugMessage(event);
		TitanPanelGuildButton_ListInitMaster();
	end
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
	TitanPanelButton_UpdateTooltip(self);
	
	GUILD_THIS = self;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OnEnter(self)
----------------------------------------------------------------------
function TitanPanelGuildButton_OnEnter(self)
	if (not (TitanGetVar(TITAN_GUILD_ID, "DisableMouseOverUpdates"))) then
		if (IsInGuild()) then
			FriendsFrame:UnregisterEvent("GUILD_ROSTER_UPDATE");
			GuildRoster();
			FriendsFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
		end
		TitanPanelGuildButton_ListInitMaster();
		TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
		TitanPanelButton_UpdateTooltip(self);
	end
	
	GUILD_THIS = self;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OnClick(self, button)
----------------------------------------------------------------------
function TitanPanelGuildButton_OnClick(self, button)
	-- open the guild pane on a left click
	if ( button == "LeftButton" and not IsControlKeyDown()) then
		if (not FriendsFrame:IsVisible()) then
		    ToggleFriendsFrame(TITAN_GUILD_TAB_NUMBER);
		    FriendsFrame_Update();
		elseif (FriendsFrame:IsVisible()) then
			ToggleFriendsFrame(TITAN_GUILD_TAB_NUMBER);
		end
	elseif ( button == "LeftButton" and IsControlKeyDown()) then
		-- forcing an update, since auto-update might be off
		FriendsFrame:UnregisterEvent("GUILD_ROSTER_UPDATE");
		if (IsInGuild()) then
			GuildRoster();
		end
		FriendsFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
		TitanPanelGuildButton_ListInitMaster();
	end
	
	GUILD_THIS = self;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OnUpdate(self, arg1)
----------------------------------------------------------------------
function TitanPanelGuildButton_OnUpdate(self, elapsed)
	-- using my own damn timer
	-- This will prevent the login delay before first update
	if (TitanGuildFirstCycle) then
		guild_TimeCounter = TitanGetVar(TITAN_GUILD_ID, "RosterUpdateTime");
		if (not (TitanGetVar(TITAN_GUILD_ID, "DisableRosterUpdates"))) then
			TitanPanelGuildButton_GetGuildRoster(timeLeft);
		end
		TitanGuildFirstCycle = false;
	else
	--if (elapsed == nil ) then
	--	elapsed = 0.01
	--end
		if (guild_TimeCounter == nil) then
			guild_TimeCounter = 0
		end
		local timeLeft = guild_TimeCounter - elapsed;
		if (timeLeft <= 0) then
			guild_TimeCounter = TitanGetVar(TITAN_GUILD_ID, "RosterUpdateTime");
			if (not (TitanGetVar(TITAN_GUILD_ID, "DisableRosterUpdates"))) then
				TitanPanelGuildButton_GetGuildRoster(timeLeft);
			end
		else
			guild_TimeCounter = timeLeft;
		end
	end
	
	GUILD_THIS = self;
end

----------------------------------------------------------------------
-- TitanPanelGuildButton_GetButtonText(id)
----------------------------------------------------------------------
function TitanPanelGuildButton_GetButtonText(id)
	-- toggling label/icon display dumps the guild count, get a fresh count
	TitanPanelGuildButton_ListInitMaster();
	local id = TitanUtils_GetButton(id);
	local NumGuild = 0;
	local buttonRichText = "";
	if (IsInGuild()) then
		NumGuild = GetNumGuildMembers();
		if (GetGuildInfo("player")) then
			TITAN_GUILD_BUTTON_LABEL = GetGuildInfo("player")..": ";
		end
		-- create string for Titan bar display
		if (GetGuildRosterShowOffline()) then
			if (numGuildOnlineFiltered > 0) then
				buttonRichText = format(TITAN_GUILD_BUTTON_TEXT_FILTERED, TitanUtils_GetGreenText(numGuildOnline), TitanUtils_GetNormalText(numGuildOnlineFiltered), TitanUtils_GetHighlightText(NumGuild));
			else
				buttonRichText = format(TITAN_GUILD_BUTTON_TEXT, TitanUtils_GetGreenText(numGuildOnline), TitanUtils_GetHighlightText(NumGuild));
			end
		else
			if (numGuildOnlineFiltered > 0) then
				buttonRichText = format(TITAN_GUILD_BUTTON_TEXT, TitanUtils_GetGreenText(numGuildOnline), TitanUtils_GetNormalText(numGuildOnlineFiltered));
			else
				buttonRichText = format(TITAN_GUILD_BUTTON_TEXT_ONLINEONLY_FORMAT, TitanUtils_GetGreenText(numGuildOnline));
			end
		end
		-- return button text
		return TITAN_GUILD_BUTTON_LABEL, buttonRichText;
	else
		return TITAN_GUILD_BUTTON_LABEL, TITAN_GUILD_NOT_IN_GUILD;
	end
end

----------------------------------------------------------------------
-- TitanPanelGuildButton_GetTooltipText()
----------------------------------------------------------------------
function TitanPanelGuildButton_GetTooltipText()
	local NumGuild = 0;
	local tooltipRichText = "";
	local guild_name = "";
	local guild_rank = "";
	local guild_rankIndex = "";
	local guild_level = "";
	local guild_class = "";
	local guild_zone = "";
	local guild_note = "";
	local guild_officernote = "";
	local guild_online = "";
	local guild_status = "";
	local guildIndex;
	local richRankText = " ";
	local showWarning = 0;
	local rowCount = 0;
	-- player is in a guild, construct the tooltip text
	if (IsInGuild()) then
		tooltipRichText = TitanUtils_GetNormalText(GetGuildInfo("player"));
		tooltipRichText = tooltipRichText.."\t"..TitanUtils_GetGreenText(TITAN_GUILD_TOOLTIP_HINT_TEXT); -- add hint
		--if (TitanGetVar(TITAN_GUILD_ID, "SortByValue")) then
		--	tooltipRichText = tooltipRichText.."\t".."Sorted by: "..TitanGetVar(TITAN_GUILD_ID, "SortByValue").."\n";
		--else
			tooltipRichText = tooltipRichText.."\n";
		--end
		-- display current filters
		if (TitanGetVar(TITAN_GUILD_ID, "FilterMyZone")) then
			tooltipRichText = tooltipRichText..TITAN_GUILD_MENU_FILTER_MYZONE..": "..GetZoneText().."\n";
		end
		if (TitanGetVar(TITAN_GUILD_ID, "FilterMyLevel")) then
			tooltipRichText = tooltipRichText..TITAN_GUILD_MENU_FILTER_MYLEVEL..": "..TitanPanelGuildButton_GetMinLevel().."-"..TitanPanelGuildButton_GetMaxLevel().."\n";
		end
		if (TitanGetVar(TITAN_GUILD_ID, "FilterClasses")) then
			tooltipRichText = tooltipRichText..TITAN_GUILD_MENU_FILTER_CLASS..": "..TitanGetVar(TITAN_GUILD_ID, "FilterClasses").."\n";
		end
		NumGuild = GetNumGuildMembers();
		for guildIndex=1, NumGuild do
			guild_name, guild_rank, guild_rankIndex, guild_level, guild_class, guild_zone, guild_note, guild_officernote, guild_online, guild_status = GetGuildRosterInfo(guildIndex);
			richRankText = TitanPanelGuildButton_ColorRankNameText(guild_rankIndex, guild_rank);
			guild_name = Ambiguate( guild_name, "guild" );
			-- on game load, the zone info is sometimes unknown
			if (not guild_zone) then
				guild_zone = " . ";
			end
			if ( guild_online ) then
				-- check for player zone and level filters
				if TitanPanelGuildButton_IsPassFilter(guild_zone, guild_level, guild_class) then
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipLevel")) then
						tooltipRichText = tooltipRichText.."  ("..TitanUtils_GetColoredText(guild_level, TG.Color["orange"])..") ";
					end
					if guild_status == 0 then guild_status = " "
					elseif guild_status == 1 then guild_status = "<AFK>"
					elseif guild_status == 2 then guild_status = "<DND>"
					end
					if (guild_status ~= " ") then
						tooltipRichText = tooltipRichText..TitanUtils_GetColoredText(guild_status, TG.Color["yellow"]).." ";
					end
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipName")) then
						tooltipRichText = tooltipRichText..TitanPanelGuildButton_ColorPlayerName(guild_name, guild_class);
					end
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipNote")) then
						if (guild_note ~= "") then
							tooltipRichText = tooltipRichText..TitanUtils_GetColoredText(" ("..guild_note..")", TG.Color["gray"]).."\t";
						else
							tooltipRichText = tooltipRichText.."\t";
						end
					else
						tooltipRichText = tooltipRichText.."\t";
					end
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipZone")) then
						tooltipRichText = tooltipRichText.." "..TitanUtils_GetColoredText(guild_zone, TG.Color["cyan"]);
					end
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipClass")) then
						tooltipRichText = tooltipRichText.." "..TitanPanelGuildButton_ColorClassName(guild_class);
					end
					if (TitanGetVar(TITAN_GUILD_ID, "ShowTooltipRank")) then
						tooltipRichText = tooltipRichText.." "..richRankText;
					end
					tooltipRichText = tooltipRichText.."\n";

				rowCount = rowCount+1
				end
			end
			-- if the tooltip limit is going to be exceeded, stop
			-- if (rowCount == TITAN_GUILD_TOOLTIP_THRESHOLD) then
			if (rowCount == TooltipSize ) then
				showWarning = 1
				break;
			end
		end

		-- add warning if too large
		if (showWarning == 1) then
			tooltipRichText = tooltipRichText.."\n"..TitanUtils_GetRedText(TITAN_GUILD_TOOLTIP_WARNING);
		end
		return tooltipRichText;
	else
		-- show a default message if the player is not in a guild
		return TitanUtils_GetNormalText(TITAN_GUILD_NOT_IN_GUILD);
	end
end

----------------------------------------------------------------------
-- Utility functions
----------------------------------------------------------------------
	TG = {};
	TG.Color = {};
	TG.Color["red"] = { r = 1.0, g = 0.0, b = 0.0 }
	TG.Color["green"] = { r = 0.0, g = 1.0, b = 0.0 }
	TG.Color["blue"] = { r = 0.0, g = 0.0, b = 1.0 }
	TG.Color["white"] = { r = 1.0, g = 1.0, b = 1.0 }
	TG.Color["magenta"] = { r = 1.0, g = 0.0, b = 1.0 }
	TG.Color["yellow"] = { r = 1.0, g = 1.0, b = 0.0 }
	TG.Color["cyan"] = { r = 0.0, g = 1.0, b = 1.0 }
	TG.Color["gray"] = { r = 0.7, g = 0.7, b = 0.7 }
	TG.Color["orange"] = { r = 1.0, g = 0.6, b = 0.0 }

	-- Gives standard class colour
	TITAN_GUILD_CLASSCOLORINDEX = {
		[1] = "|cffff7d0a",
		[2] = "|cffabd473",
		[3] = "|cff69ccf0",
		[4] = "|cfff58cba",
		[5] = "|cffffffff",
		[6] = "|cfffff569",
		[7] = "|cff2459ff",
		[8] = "|cff9482ca",
		[9] = "|cffc79c6e",
		[10] = "|cffc41f3b",
		[11] = "|cff00ff96",
                [12] = "|cffa330c9",
	}

----------------------------------------------------------------------
--  TitanPanelGuildButton_ColorClassName()
--  colors the class name based on the raid colors
----------------------------------------------------------------------
function TitanPanelGuildButton_ColorClassName(className)
	local i = TITAN_GUILD_CLASSINDEX[className];
	local coloredClassText = TITAN_GUILD_CLASSCOLORINDEX[i]..className.."|r";
	return coloredClassText;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ColorPlayerName()
--  colors the player name based on the raid colors
----------------------------------------------------------------------
function TitanPanelGuildButton_ColorPlayerName(playerName, className)
	local i = TITAN_GUILD_CLASSINDEX[className];
	local coloredPlayerName = TITAN_GUILD_CLASSCOLORINDEX[i]..playerName.."|r";
	return coloredPlayerName;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SortGuildRoster()
--  executes the SortGuildRoster function and updates the button
----------------------------------------------------------------------
function TitanPanelGuildButton_SortGuildRoster()
	-- if a stored sort value exists, then sort
	--guildPrintDebugMessage(TitanGetVar(TITAN_GUILD_ID, "SortByValue"));
	if (TitanGetVar(TITAN_GUILD_ID, "SortByValue")) then
		SortGuildRoster(string.lower(TitanGetVar(TITAN_GUILD_ID, "SortByValue")));
	end
	--guildPrintDebugMessage("Done sorting");
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SetSortByValue()
--  persist the user's sort selection
----------------------------------------------------------------------
function TitanPanelGuildButton_SetSortByValue(value)
	TitanSetVar(TITAN_GUILD_ID, "SortByValue", value);
	-- conduct the sort
	TitanPanelGuildButton_SortGuildRoster()
	TitanPanelGuildButton_CloseMenu();
	TitanPanelGuildButton_ListInitMaster();
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
	TitanPanelButton_UpdateTooltip(self);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SetTooltipChoice()
--  used to config the tooltip output
----------------------------------------------------------------------
function TitanPanelGuildButton_SetTooltipChoice(value)
	local tooltipConfigVar = "ShowTooltip"..value;
	TitanToggleVar(TITAN_GUILD_ID, tooltipConfigVar);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SetRosterUpdateTime()
--  persist the roster update time selection
----------------------------------------------------------------------
function TitanPanelGuildButton_SetRosterUpdateTime(value)
	--guildPrintDebugMessage(this.value);
	TitanSetVar(TITAN_GUILD_ID, "RosterUpdateTime", value);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_CloseMenu()
----------------------------------------------------------------------
function TitanPanelGuildButton_CloseMenu()
	TitanPanelRightClickMenu_Close()
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleAdvancedMenus()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleAdvancedMenus()
	TitanToggleVar(TITAN_GUILD_ID, "ShowAdvancedMenus");
	TitanPanelGuildButton_ListInitMaster()
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleShowMenuOptions()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleShowMenuOptions()
	TitanToggleVar(TITAN_GUILD_ID, "ShowMenuOptions");
	TitanPanelGuildButton_ListInitMaster();
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleFilterMyLevel()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleFilterMyLevel()
	TitanToggleVar(TITAN_GUILD_ID, "FilterMyLevel");
	TitanPanelGuildButton_CloseMenu();
	TitanPanelGuildButton_ListInitMaster();
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleFilterMyZone()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleFilterMyZone()
	TitanToggleVar(TITAN_GUILD_ID, "FilterMyZone");
	TitanPanelGuildButton_CloseMenu();
	TitanPanelGuildButton_ListInitMaster();
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleRosterUpdates()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleRosterUpdates()
	TitanToggleVar(TITAN_GUILD_ID, "DisableRosterUpdates");
	TitanPanelGuildButton_ListInitMaster()
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ToggleMouseOverUpdates()
----------------------------------------------------------------------
function TitanPanelGuildButton_ToggleMouseOverUpdates()
	TitanToggleVar(TITAN_GUILD_ID, "DisableMouseOverUpdates");
	TitanPanelGuildButton_ListInitMaster()
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_AddClassFilter()
----------------------------------------------------------------------
function TitanPanelGuildButton_AddClassFilter(className)
	if (className == "All") then
		TitanSetVar(TITAN_GUILD_ID, "FilterClasses", TITAN_NIL);
	else
		TitanSetVar(TITAN_GUILD_ID, "FilterClasses", className);
	end
	TitanPanelGuildButton_CloseMenu();
	TitanPanelGuildButton_ListInitMaster();
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_GuildWhisper()
----------------------------------------------------------------------
-- send a /w chat command
function TitanPanelGuildButton_GuildWhisper(name)
	if ( not ChatFrame1EditBox:IsVisible() ) then
		ChatFrame_OpenChat("/w".." "..name.." ");
	else
		ChatFrame1EditBox:SetText("/w".." "..name.." ");
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OpenGuildChat()
----------------------------------------------------------------------
-- send a /g chat command
function TitanPanelGuildButton_OpenGuildChat()
	if ( not ChatFrame1EditBox:IsVisible() ) then
		ChatFrame_OpenChat("/g");
	else
		ChatFrame1EditBox:SetText("/g");
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_OpenGuildOfficerChat()
----------------------------------------------------------------------
-- send a /o chat command
function TitanPanelGuildButton_OpenGuildOfficerChat()
	if ( not ChatFrame1EditBox:IsVisible() ) then
		ChatFrame_OpenChat("/o");
	else
		ChatFrame1EditBox:SetText("/o");
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_InviteToGroup()
----------------------------------------------------------------------
-- invoke invite to group command
function TitanPanelGuildButton_InviteToGroup(name)
	InviteUnit(name)
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SendWhoRequest()
----------------------------------------------------------------------
-- invoke a /who query on a guild member
function TitanPanelGuildButton_SendWhoRequest(name)
	C_FriendList.SendWho(name);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_AddFriend()
----------------------------------------------------------------------
-- add a guild member to your friends list
function TitanPanelGuildButton_AddFriend(name)
	C_FriendList.AddFriend(name);
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_CheckForFrame(frameName)
----------------------------------------------------------------------
-- check for frames which only exist for certain classes
function TitanPanelGuildButton_CheckForFrame(frameName)
	if (frameName) then
		return frameName:IsVisible();
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_GetMinLevel()
----------------------------------------------------------------------
-- get the min level for filtering
function TitanPanelGuildButton_GetMinLevel()
	local playerLevel = UnitLevel("player");
	local levelMin = 1;
	if (playerLevel <= TITAN_GUILD_LEVEL_RANGE) then
		levelMin = 1;
	else
		levelMin = playerLevel - TITAN_GUILD_LEVEL_RANGE;
	end
	return levelMin;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_GetMaxLevel()
----------------------------------------------------------------------
-- get the max level for filtering
function TitanPanelGuildButton_GetMaxLevel()
	local playerLevel = UnitLevel("player");
	local levelMax = TITAN_GUILD_LEVEL_MAX_CAP;
	if (playerLevel + TITAN_GUILD_LEVEL_RANGE >= TITAN_GUILD_LEVEL_MAX_CAP) then
		levelMax = TITAN_GUILD_LEVEL_MAX_CAP;
	else
		levelMax = playerLevel + TITAN_GUILD_LEVEL_RANGE;
	end
	return levelMax;
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ColorRankNameText(guild_rankIndex, guild_rank)
----------------------------------------------------------------------
function TitanPanelGuildButton_ColorRankNameText(guild_rankIndex, guild_rank)
	local green = GREEN_FONT_COLOR;		-- 0.1, 1.00, 0.1
	local yellow = NORMAL_FONT_COLOR;	-- 1.0, 0.82, 0.0
	local red = RED_FONT_COLOR;				-- 1.0, 0.10, 0.1

	local color = {};
	local index = guild_rankIndex;
	local nRanks = GuildControlGetNumRanks();
	local pct = ((guild_rankIndex*100)/nRanks)/100;
	local colortxt = "";
	if (index == 0) then
		color = red;
	elseif (index == (nRanks/2)) then
		color = yellow;
	elseif (index == nRanks) then
		color = green;
	elseif (index > (nRanks/2)) then
		local pctmod = (1.0 - pct) * 2;
		color.r =(yellow.r - green.r)*pctmod + green.r;
		color.g = (yellow.g - green.g)*pctmod + green.g;
		color.b = (yellow.b - green.b)*pctmod + green.b;
	elseif (index < (nRanks/2)) then
		local pctmod = (0.5 - pct) * 2;
		color.r = (red.r - yellow.r)*pctmod + yellow.r;
		color.g = (red.g - yellow.g)*pctmod + yellow.g;
		color.b = (red.b - yellow.b)*pctmod + yellow.b;
	end
	colortxt = TitanUtils_GetColoredText(guild_rank, color);
	return colortxt;
end

-- used for chat frame based debug messaging
function guildPrintDebugMessage(msg)
	if( DEFAULT_CHAT_FRAME ) then
		DEFAULT_CHAT_FRAME:AddMessage("<GUILD_DEBUG> "..msg);
	end
end

----------------------------------------------------------------------
-- TitanPanelGuildButton_GetGuildRoster(timer)
-- time based wrapper for the GuildRoster() call
-- calling based on a countdown from TitanGetVar(TITAN_GUILD_ID, "RosterUpdateTime")
----------------------------------------------------------------------
function TitanPanelGuildButton_GetGuildRoster(timer)
	if (timer and timer <= 0) then
		if (IsInGuild()) then
			FriendsFrame:UnregisterEvent("GUILD_ROSTER_UPDATE");
			--guildPrintDebugMessage("Calling GuildRoster()");
			GuildRoster();
			FriendsFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
			-- reset the timer to full ... EMERALD: Only do this reset on positive hit
			guild_TimeCounter = TitanGetVar(TITAN_GUILD_ID, "RosterUpdateTime");
		end
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ConstructGuildTable()
--  constructs a table used to generate the right-click menu nav
----------------------------------------------------------------------
function TitanPanelGuildButton_ConstructGuildTable()
	local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status
	local rankTable = {};
	local rankMembers = {};
	masterTable = {};
	local gIndex;
	local rIndex;
	local guildNum = GetNumGuildMembers();
	local numRanks = GuildControlGetNumRanks();
	local rankMemberTablePos;
	-- for all ranks, create the tabled used for the right-click menus
	for rIndex=1, numRanks do
		rankMembers = {};
		rankTable = {};
		rankMemberTablePos = 1;
		-- insert the rank name at pos 1
		rankTable.rank = GuildControlGetRankName(rIndex);
		for gIndex=1, guildNum do
			g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status = GetGuildRosterInfo(gIndex);
			-- guildPrintDebugMessage("g_name: "..g_name..", g_rank: "..g_rank..", g_rankIndex: "..g_rankIndex..", g_level: "..g_level..", g_class: "..g_class..", g_zone: "..g_zone..", g_note: "..g_note..", g_officernote: "..g_officernote..", g_online: "..g_online..", g_status: "..g_status);
			-- guild rank index might be zero based, so add 1
			g_rankIndex = g_rankIndex + 1;
			-- check if online before adding to table
			if ( g_online ) then
				-- check filters before adding to table
				if TitanPanelGuildButton_IsPassFilter(g_zone, g_level, g_class) then
					if (g_rankIndex == rIndex) then
						--guildPrintDebugMessage("MATCH guild_rankIndex: "..g_rankIndex.." = "..rIndex.." "..g_name.." "..g_rank);
						table.insert(rankMembers, rankMemberTablePos, g_name);
						--guildPrintDebugMessage(rankMembers[rankMemberTablePos]);
						rankMemberTablePos = rankMemberTablePos + 1;
					end
				end
			end
		end
		rankTable.members = rankMembers;
		table.insert(masterTable, rIndex, rankTable);
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ConstructSimpleGuildTable()
--  constructs a table used to generate the flat right-click nav
----------------------------------------------------------------------
function TitanPanelGuildButton_ConstructSimpleGuildTable()
	local g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status
	masterTableSimple = {};
	local gIndex;
	local rIndex;
	local guildNum = GetNumGuildMembers();
	local simpleMemberTablePos = 1;
	for gIndex=1, guildNum do
		g_name, g_rank, g_rankIndex, g_level, g_class, g_zone, g_note, g_officernote, g_online, g_status = GetGuildRosterInfo(gIndex);
		-- check if online before adding to table
		if ( g_online ) then
			-- check filters before adding to table
			if TitanPanelGuildButton_IsPassFilter(g_zone, g_level, g_class) then
				-- insert into a flat table for rendering the simple menus
				local filteredPlayer = {name=g_name,rankIndex=g_rankIndex};
				table.insert(masterTableSimple, simpleMemberTablePos, filteredPlayer);
				simpleMemberTablePos = simpleMemberTablePos + 1;
			end
		end
	end
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_ListInitMaster()
--  wrapper for several functions called on a list update
----------------------------------------------------------------------
function TitanPanelGuildButton_ListInitMaster()
	TitanPanelGuildButton_InitPaging();
	TitanPanelGuildButton_ComputeOnlineGuildMembers();
	TitanPanelGuildButton_ComputePages();
	TitanPanelGuildButton_ConstructSimpleGuildTable();
	TitanPanelGuildButton_ConstructGuildTable();
end

----------------------------------------------------------------------
--  TitanPanelGuildButton_SetTooltipSize()
--  Changes how much is shown in the guild tooltip
----------------------------------------------------------------------
function TitanPanelGuildButton_SetTooltipSize(self)
	local i = self.value
	TitanSetVar(TITAN_GUILD_ID, "TooltipSize", i);
	TitanPanelButton_UpdateButton(TITAN_GUILD_ID);
	return;
end
