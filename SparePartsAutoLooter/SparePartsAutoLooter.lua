SPAL = {}
SPAL.Frame = CreateFrame("FRAME")
SPAL.addon_name = "SparePartsAutoLooter"

--assuming ML is off by default
SPAL.MasterLooter = false

SPAL.red = "EE160B"
SPAL.yellow = "FFFC25"
SPAL.orange = "FC5215"
SPAL.green = "249904"

function SPAL.Colorfy(msg,color)
	return "|cff"..color..msg.."|r"
end

SPAL.addon_title = "<"..SPAL.Colorfy("Spare Parts",SPAL.red).." "..SPAL.Colorfy("Auto Looter",SPAL.yellow)..">"
SPAL.short_addon_title = "<"..SPAL.Colorfy("SP",SPAL.red)..SPAL.Colorfy("AL",SPAL.yellow)..">"

SPAL.DefaultAutoLootList = {
	--default itemids to autoloot to the master looter
	[32227] = "Belois", -- Crimson Spinel, Red
	[32228] = "Belois", -- Empyrean Sapphire, Blue
	[32229] = "Belois", -- Lionseye, Yellow
	[32231] = "Belois", -- Pyrestone, Pyrestone
	[32249] = "Belois", -- Seaspray Emerald, Green
	[32230] = "Belois", -- Shadowsong Amethyst, Purple
	[32428] = "__masterlooter__" -- Heart of Darkness
}

local function split(str, pat, limit)
	local t = {}
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(t, cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
  
		if limit ~= nil and limit <= #t then
			break
		end
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

local function firstToUpper(str)
    return (str:gsub("^%l", string.upper))
end

function SPAL.Msg(msg,title)
	-- title = nil to print long title
	--         false to suppress title
	--         true to print short title
	short = title or (title == nil and false)
	title = title or (title == nil and true)
	DEFAULT_CHAT_FRAME:AddMessage((title and (short and SPAL.short_addon_title or SPAL.addon_title).." " or "")..msg)
	return
end

local function logAutoLootItem(itemLink, memName)
	local mydate = date("%Y-%m-%d")
	local mytime = date("%H:%M:%S")

	local itemName = GetItemInfo(itemLink)

	if not SPALHistory[mydate] then
		SPALHistory[mydate] = {}
	end
	if not SPALHistory[mydate][mytime] then
		SPALHistory[mydate][mytime] = {}
	end

	table.insert(SPALHistory[mydate][mytime], memName.." received "..itemLink)
end

local function AutoLootItem(li, itemLink)
	local distributed = false
	local itemId = tonumber(string.match(itemLink, "item:(%d*)"))
	local autolooters = split(SPALConfig.AutoLootList[itemId], " ")

	local memName = UnitName("player")
	if autolooters[1] == "__masterlooter__" then
		autolooters[1] = memName
	else
		autolooters[#autolooters+1] = memName
	end

	for al = 1, #autolooters do
		local eligible = false
		for ci = 1, GetNumGroupMembers() do
			if GetMasterLootCandidate(li, ci) == autolooters[al] then
				eligible = ci
				break
			end
		end
		
		if eligible then
			SPAL.Msg("Auto looting "..itemLink.." to "..autolooters[al], true)
			logAutoLootItem(itemLink, autolooters[al])
			GiveMasterLoot(li, eligible)
			distributed = true
			return distributed
		end
	end

	return distributed
end

function SPAL.EventHandler(self, event, ...)
	if event == "ADDON_LOADED" then
		local addon_name = ...
		if addon_name == SPAL.addon_name then
			if not SPALConfig then
				SPAL.Msg("Initializing addon from defaults.")
				SPALConfig = {}
				SPALConfig.Enabled = true
				for itemid,autolooter in pairs(SPAL.DefaultAutoLootList) do
					local itemName,itemLink = GetItemInfo(itemid)
					SPALConfig.AutoLootList[itemLink] = autolooter
				end
			end
			if not SPALHistory then
				SPALHistory = {}
			end
			SPAL.Msg("Addon loaded!")

			local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
			if lootmethod == "master" then
				SPAL.MasterLooter = true
			else
				SPAL.MasterLooter = false
			end

			return
		end
	elseif event == "PLAYER_LOGOUT" then
		return
	end
	
	if not SPALConfig.Enabled then
		-- Addon disabled, business as usual.
		return
	end

	local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()

	if lootmethod == "master" and masterlooterPartyID == 0 then
		for li = 1, GetNumLootItems() do
			local itemLink = GetLootSlotLink(li)
			if itemLink then
				local itemName = GetItemInfo(itemLink)
				if itemName then
					local itemId = tonumber(string.match(itemLink, "item:(%d*)"))
					if itemId then
						if SPALConfig.AutoLootList[itemId] then
							local distributed = AutoLootItem(li, itemLink)
							if not distributed then
								SPAL.Msg("Unable to auto loot "..itemLink, true)
							end
							break
						end
					end
				end
			end
		end
	end
end

function SPAL.SlashCommand(input)
	input = string.lower(input)

	local cmd
	local args

	if input == "" then
		cmd = "help"
	else
		args = split(input, " ", 1)
		if #args then
			cmd = args[1]
			input = table.concat(args, " ", 2)
		end
	end	

	if string.find(cmd,"help") then
	elseif string.find(cmd,"enable") then
		SPALConfig.Enabled = true
		SPAL.Msg("Enabled.",true)
		return

	elseif string.find(cmd,"disable") then
		SPALConfig.Enabled = false
		SPAL.Msg("Disabled.",true)
		return

	elseif string.find(cmd,"reset") then
		SPALConfig = {}
		SPALConfig.Enabled = true
		SPALConfig.AutoLootList = SPAL.DefaultAutoLootList
		for itemid,autolooter in pairs(SPAL.DefaultAutoLootList) do
			local itemName,itemLink = GetItemInfo(itemid)
			SPALConfig.AutoLootList[itemLink] = autolooter
		end
		SPAL.Msg("has been reset to defaults.")
		return

	elseif string.find(cmd,"history") then
		local args = split(input, " ")
		if #args == 1 and args[1] == "delete" then
			SPAL.Msg("Deleting Auto Loot History.",true)
			SPALHistory = {}
			return
		elseif #args >= 1 then
			SPAL.Msg("Unknown option supplied.",true)
			return
		end

		SPAL.Msg("Auto Loot History")
		local history = false
		for mydate,data in pairs(SPALHistory) do
			for mytime,logentry in pairs(SPALHistory[mydate]) do
				for i = 1, #SPALHistory[mydate][mytime] do
					history = true
					SPAL.Msg(mydate.." "..mytime..": "..SPALHistory[mydate][mytime][i],true)
				end
			end
		end
		if not history then
			SPAL.Msg(" *** No history recorded.",true)
		end

		return
		
	elseif string.find(cmd,"status") then
		if SPALConfig.Enabled then
			local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
			SPAL.Msg(SPAL.Colorfy("ENABLED",SPAL.green))
			if lootmethod == "master" then
				if masterlooterPartyID == 0 then
					SPAL.Msg("Master Looter: "..SPAL.Colorfy("ENABLED",SPAL.green),false)
				else
					SPAL.Msg("Master Looter: "..SPAL.Colorfy("ENABLED",SPAL.green)..SPAL.Colorfy(" BUT YOU ARE NOT THE MASTER LOOTER.",SPAL.red),false)
				end
				if not masterlooterRaidID then
					SPAL.Msg("Raid: "..SPAL.Colorfy("DISABLED",SPAL.red),false)
					SPAL.MasterLooter = false
				else
					SPAL.MasterLooter = true
				end
			else
				SPAL.Msg("Master Looter: "..SPAL.Colorfy("DISABLED",SPAL.red),false)
			end
			local autolootempty = true
			SPAL.Msg("Auto looting is configured for the following items:",false)
			for itemid,autolooter in pairs(SPALConfig.AutoLootList) do
				autolooter = (autolooter == "__masterlooter__" and "Master Looter" or (autolooter == "__roundrobin__" and "awarded round-robin" or autolooter))
				local itemName,itemLink,_,_,_,_,_,_,_,_,_ = GetItemInfo(itemid)
				SPAL.Msg("> "..itemLink.." ==> "..autolooter,false)
				autolootempty = false
			end
			if autolootempty then
				SPAL.Msg(" *** No auto loot rules are configured.",false)
			end
			return
		end
		SPAL.Msg("Auto looting is currently disabled.",true)
		return

	elseif string.find(cmd,"autoloot") or string.find(cmd,"roundrobin") then
		if input == "" then
			-- Requires an item!
			SPAL.Msg(SPAL.Colorfy("This option requires at least one argument: itemid or itemlink!", SPAL.red),false)
			return
		end

		local autolooters = {}
		local itemids = {}

		local args
		args = split(input, "]")
		if #args == 1 then
			args = split(input, " ")
		end

		for i = 1, #args do
			local _,itemLink,_,_,_,_,_,_,_,_,_ = GetItemInfo(args[i])
			if itemLink then
				-- item found
				local itemid = itemLink:match("item:(%d+):")
				table.insert(itemids,tonumber(itemid))
			else
				local options = split(args[i]," ")
				for j = 1, #options do
					local option = options[j]:gsub('%W','')
					if option:len() > 2 then
						table.insert(autolooters, firstToUpper(option))
					end
				end
			end
		end
		if #autolooters > 0 and cmd == "roundrobin" then
			SPAL.Msg(SPAL.Colorfy("Do not specify any loot recipients when using round-robin looting.", SPAL.red),false)
			return
		elseif #autolooters == 0 then
			table.insert(autolooters, (cmd == "autoloot" and "__masterlooter__" or "__roundrobin__"))
		end

		local autolooterstring = table.concat(autolooters, " ")

		for i = 1, #itemids do
			local _,itemLink,_,_,_,_,_,_,_,_,_ = GetItemInfo(itemids[i])

			if SPALConfig.AutoLootList[itemids[i]] == autolooterstring then
				-- already there, remove the item
				SPALConfig.AutoLootList[itemids[i]] = nil
				SPAL.Msg(SPAL.Colorfy("REMOVING", SPAL.red).." auto loot rule for "..itemLink, true)
			elseif SPALConfig.AutoLootList[itemids[i]] then
				SPALConfig.AutoLootList[itemids[i]] = autolooterstring
				autolooterstring = autolooterstring:gsub("__masterlooter__", "Master Looter")
				autolooterstring = autolooterstring:gsub("__roundrobin__", "Round-Robin")
				SPAL.Msg(SPAL.Colorfy("UPDATING", SPAL.orange).." auto loot rule for "..itemLink.." to "..autolooterstring, true)
			else
				SPALConfig.AutoLootList[itemids[i]] = autolooterstring
				autolooterstring = autolooterstring:gsub("__masterlooter__", "Master Looter")
				autolooterstring = autolooterstring:gsub("__roundrobin__", "Round-Robin")
				SPAL.Msg(SPAL.Colorfy("ADDING", SPAL.green).." auto loot rule for "..itemLink.." to "..autolooterstring, true)
			end
		end

		return
	else
		-- argument provided but not matched
		SPAL.Msg("Unknown option supplied.",true)
	end
	SPAL.Msg(" ")
	SPAL.Msg(SLASH_SPAL1.." [enable|disable]|r",false)
	SPAL.Msg("         - Enable or disable auto looting.",false)
	SPAL.Msg(" ",false)
	SPAL.Msg(SLASH_SPAL1.." history [delete]|r",false)
	SPAL.Msg("         - View the auto loot log. Optionally delete the full history.",false)
	SPAL.Msg(" ",false)
	SPAL.Msg(SLASH_SPAL1.." autoloot <itemid|itemlink> <player name>|r",false)
	SPAL.Msg("         - Set or remove <player name> as the recipient of <item>.",false)
	SPAL.Msg(" ",false)
	SPAL.Msg(SLASH_SPAL1.." roundrobin <itemid|itemlink>|r",false)
	SPAL.Msg("         - Enable round-robin mode for <item>.",false)
	SPAL.Msg(" ",false)
	SPAL.Msg(SLASH_SPAL1.." status|r",false)
	SPAL.Msg("         - View current addon status and auto loot rules.",false)
	SPAL.Msg(" ",false)
	SPAL.Msg(SLASH_SPAL1.." reset|r",false)
	SPAL.Msg("         - Reset all settings back to default.",false)
	return
end

SLASH_SPAL1, SLASH_SPAL2, SLASH_SPAL3 = "/spal","/sparepartsautolooter","/autolooter"
SlashCmdList["SPAL"] = SPAL.SlashCommand

SPAL.Frame:SetScript("OnEvent", SPAL.EventHandler);
SPAL.Frame:RegisterEvent("ADDON_LOADED")
SPAL.Frame:RegisterEvent("PLAYER_LOGOUT")
SPAL.Frame:RegisterEvent("LOOT_OPENED")
