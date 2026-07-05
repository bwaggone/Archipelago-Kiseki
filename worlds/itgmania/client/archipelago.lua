-- Module configuration
local AP = {}

-- Constants. URL / Slot / Password need manual adjusting.
local HOST = "ws://localhost:38281"
local SLOT = "ITGManiaPlayer"
local PASSWORD = ""
local MODULE_TAG = "[AP-SLmodule]"
local ENABLE_PENDING_SCORES = true -- Enable saving failed score submissions for retry when offline
local MAX_PENDING_SCORES = 50      -- Maximum number of pending scores stored per player

-- global to this mod
local GAME_NAME = "ITGMania"

SCREENMAN:SystemMessage("Hola from lua!")

-- Guarded stub declarations (only for tooling; real objects provided by engine at runtime)
if not PROFILEMAN then PROFILEMAN = { GetProfileDir = function(...) return "" end } end
if not NETWORK then NETWORK = { HttpRequest = function(...) return {} end } end
if not FILEMAN then FILEMAN = { DoesFileExist = function(...) return false end, GetDirListing = function(...) return {} end, Remove = function(...) return true end } end

-- Only allow one instance of the ap handler.

local apHandler = nil
local apHandlerInstance = nil
local apHandlerShuttingDown = false
local itemNames = {}
local locationIds = {}
local folderToChartName = {}
local seedName = "Unknown"
local AP_AllReceivedItems = {}
local slotOptions = {
	score_type = 1,
	passing_score = 0,
	fail_allowed = false,
}

GetAPHandlerInstance = function()
	return apHandlerInstance
end


local CreateRequest = function(event, data)
	return JsonEncode({
		event=event,
		data=data
	})
end


local UpdatePlaylist = function()
	if seedName == "Unknown" then return end
	local path = THEME:GetCurrentThemeDirectory() .. "Other/Playlists/Archipelago - " .. seedName .. ".txt"
	local playlist_content = "--- Archipelago\n"
	local count = 0
	
	for _, item in ipairs(AP_AllReceivedItems) do
		local item_id = item.item
		local item_name = itemNames[item_id]
		if item_name then
			-- Parse the path to get only the song directory name (the middle part in Group/Folder/File)
			local parts = {}
			for part in item_name:gmatch("[^/]+") do
				table.insert(parts, part)
			end
			local songFolder = nil
			if #parts >= 2 then
				songFolder = parts[2]
			elseif #parts == 1 then
				songFolder = parts[1]
			end
			
			if songFolder then
				playlist_content = playlist_content .. songFolder .. "\n"
				count = count + 1
				if not SONGMAN:FindSong(songFolder) then
					Trace("Archipelago warning: Received song is not installed: " .. songFolder)
				end
			end
		end
	end
	
	if count > 0 then
		local file = RageFileUtil.CreateRageFile()
		if file:Open(path, 2) then
			file:Write(playlist_content)
			file:Close()
			file:destroy()
			SM("Updated Archipelago playlist: " .. count .. " songs")
		else
			Trace("Archipelago error: Could not open '" .. path .. "' to write playlist.")
		end
	end
end

local EvaluateCompletedSong = function()
	local song = GAMESTATE:GetCurrentSong()
	if not song then return end
	
	local songFilePath = song:GetSongFilePath()
	if not songFilePath then return end
	
	-- Extract the folder name from the song's virtual directory path
	local songDir = song:GetSongDir()
	local parts = {}
	for part in songDir:gmatch("[^/]+") do
		table.insert(parts, part)
	end
	local folderName = parts[#parts]
	
	if not folderName then return end
	
	-- Verify if the song is part of the Archipelago run by looking up its folder name
	local chart_name = folderToChartName[folderName]
	if not chart_name then
		-- Not an AP song, ignore silently
		return
	end
	
	SM("Evaluating completed AP song: " .. chart_name)
	
	local checks_to_send = {}
	local queue_check = function(suffix)
		local loc_name = chart_name .. "-" .. suffix
		local loc_id = locationIds[loc_name]
		if loc_id then
			table.insert(checks_to_send, loc_id)
		end
	end
	
	for _, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
		local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(pn)
		if pss then
			local is_failed = pss:GetFailed()
			local moneyPercent = pss:GetPercentDancePoints() * 100
			
			-- EX Percent and High EX Percent (High EX has use_actual_w0_weight = true)
			local exPercent = 0
			local highExPercent = 0
			if CalculateExScore then
				local success_ex, val_ex = pcall(CalculateExScore, pn)
				if success_ex then exPercent = val_ex end
				
				local success_hex, val_hex = pcall(CalculateExScore, pn, nil, true)
				if success_hex then highExPercent = val_hex end
			else
				Trace("Archipelago warning: CalculateExScore function not found in global scope!")
			end
			
			-- Select score percentage based on option
			local activePercent = moneyPercent
			local score_system_name = "Money"
			if slotOptions.score_type == 1 then
				activePercent = exPercent
				score_system_name = "EX"
			elseif slotOptions.score_type == 2 then
				activePercent = highExPercent
				score_system_name = "High EX (FA+)"
			end
			
			SM("Player " .. ToEnumShortString(pn) .. " Performance - " .. score_system_name .. " Score: " .. string.format("%.2f", activePercent) .. "% (Money: " .. string.format("%.2f", moneyPercent) .. "%" .. (CalculateExScore and (", EX: " .. string.format("%.2f", exPercent) .. "%") or "") .. "), Failed: " .. tostring(is_failed))
			
			-- Check clear condition
			local fail_allowed = (slotOptions.fail_allowed == true or slotOptions.fail_allowed == 1)
			local passed_clear = false
			if not is_failed or fail_allowed then
				if activePercent >= slotOptions.passing_score then
					passed_clear = true
				end
			end
			
			if passed_clear then
				SM("Player " .. ToEnumShortString(pn) .. " CLEARED the song logic!")
				queue_check("0")
				queue_check("1")
				
				-- Check score thresholds
				if activePercent >= 85 then queue_check("85") end
				if activePercent >= 90 then queue_check("90") end
				if activePercent >= 96 then queue_check("96") end
				if activePercent >= 98 then queue_check("98") end
				if activePercent >= 99 then queue_check("99") end
			else
				SM("Player " .. ToEnumShortString(pn) .. " did not clear the song logic (Passing Score target: " .. tostring(slotOptions.passing_score) .. "%)")
			end
			
			-- Quad and Quint are independent of the selected score_type
			if moneyPercent >= 100 then
				SM("Player " .. ToEnumShortString(pn) .. " got a QUAD money score!")
				queue_check("quad")
			end
			if exPercent >= 100 and CalculateExScore then
				SM("Player " .. ToEnumShortString(pn) .. " got a QUINT EX score!")
				queue_check("quint")
			end
		end
	end
	
	if #checks_to_send > 0 and apHandlerInstance and apHandlerInstance.connected and apHandlerInstance.socket then
		SM("Sending " .. tostring(#checks_to_send) .. " location checks to server...")
		local checks_packet = {
			["cmd"] = "LocationChecks",
			locations = checks_to_send
		}
		local payload = JsonEncode({ checks_packet })
		apHandlerInstance.socket:Send(payload, false)
	else
		SM("No locations to check or client is not connected.")
	end
end

-- HTTP Communication
CreateAPHandler = function() 
  if apHandler == nil then
    apHandler = Def.ActorFrame{
      Name="ArchipelagoHandler",
		InitCommand=function(self)
			apHandlerInstance = self
			apHandlerShuttingDown = false
			self.socket = nil
			self.connected = false
			self.errorMsg = nil

			SM("Connecting to Archipelago server at: " .. HOST)

			-- Connection time.
			self.socket = NETWORK:WebSocket{
				url=HOST,
				pingInterval=15,
				automaticReconnect=true,
				onMessage=function(msg)
					if msg.type == "WebSocketMessageType_Open" then
						SM("WebSocket transport connected. Waiting for RoomInfo...")
					elseif msg.type == "WebSocketMessageType_Close" then
						self.connected = false
						SM("Archipelago connection closed: " .. tostring(msg.reason))
					elseif msg.type == "WebSocketMessageType_Error" then
						self.connected = false
						SM("Archipelago connection error: " .. tostring(msg.reason))
					elseif msg.type == "WebSocketMessageType_Message" then
						local success, packets = pcall(JsonDecode, msg.data)
						if not success then
							SM("Failed to decode JSON from Archipelago server: " .. tostring(msg.data))
							return
						end

						for _, packet in ipairs(packets) do
							local packet_cmd = packet["cmd"]
							if packet_cmd == "RoomInfo" then
								seedName = packet["seed_name"] or "Unknown"
								SM("Received RoomInfo (Seed: " .. seedName .. "). Requesting DataPackage...")
								local get_dp_packet = {
									["cmd"] = "GetDataPackage",
									games = { GAME_NAME }
								}
								local payload = JsonEncode({ get_dp_packet })
								self.socket:Send(payload, false)
							elseif packet_cmd == "DataPackage" then
								local games = packet.data and packet.data.games
								local game_data = games and games[GAME_NAME]
								local item_to_id = game_data and game_data.item_name_to_id
								local location_to_id = game_data and game_data.location_name_to_id

								itemNames = {}
								local count = 0
								if item_to_id then
									for name, id in pairs(item_to_id) do
										itemNames[id] = name
										count = count + 1
									end
								end

								locationIds = {}
								folderToChartName = {}
								local loc_count = 0
								local cached_folders = 0
								if location_to_id then
									for name, id in pairs(location_to_id) do
										locationIds[name] = id
										loc_count = loc_count + 1
										
										if name:match("%-0$") then
											local base_chart = name:gsub("%-0$", "")
											local parts = {}
											for part in base_chart:gmatch("[^/]+") do
												table.insert(parts, part)
											end
											local folderName = nil
											if #parts >= 2 then
												folderName = parts[2]
											elseif #parts == 1 then
												folderName = parts[1]
											end
											if folderName then
												folderToChartName[folderName] = base_chart
												cached_folders = cached_folders + 1
											end
										end
									end
								end
								SM("Loaded " .. tostring(count) .. " item names, " .. tostring(loc_count) .. " locations, and " .. tostring(cached_folders) .. " folder mappings from DataPackage.")

								SM("Sending Connect packet...")
								local connect_packet = {
									["cmd"] = "Connect",
									game = GAME_NAME,
									name = SLOT,
									uuid = "itgmania-ap-client-uuid",
									version = { major = 0, minor = 6, build = 8, ["class"] = "Version" },
									items_handling = 7, -- Receive all items (remote, own, starting)
									password = PASSWORD,
									tags = {},
									slot_data = true
								}
								local connect_payload = JsonEncode({ connect_packet })
								self.socket:Send(connect_payload, false)
							elseif packet_cmd == "Connected" then
								self.connected = true
								SM("Successfully connected to Archipelago! Slot: " .. tostring(packet.slot))
								if packet["slot_data"] then
									slotOptions.score_type = packet["slot_data"]["score_type"] or 1
									slotOptions.passing_score = packet["slot_data"]["passing_score"] or 0
									slotOptions.fail_allowed = packet["slot_data"]["fail_allowed"]
									SM("Slot Options - Score Type: " .. tostring(slotOptions.score_type) .. 
									   ", Passing Score: " .. tostring(slotOptions.passing_score) .. 
									   ", Fail Allowed: " .. tostring(slotOptions.fail_allowed))
								end
							elseif packet_cmd == "RoomUpdate" then
								SM("Received RoomUpdate from server.")
								if packet["slot_data"] then
									slotOptions.score_type = packet["slot_data"]["score_type"] or slotOptions.score_type
									slotOptions.passing_score = packet["slot_data"]["passing_score"] or slotOptions.passing_score
									slotOptions.fail_allowed = packet["slot_data"]["fail_allowed"] or slotOptions.fail_allowed
									SM("Updated Slot Options - Score Type: " .. tostring(slotOptions.score_type) .. 
									   ", Passing Score: " .. tostring(slotOptions.passing_score) .. 
									   ", Fail Allowed: " .. tostring(slotOptions.fail_allowed))
								end
							elseif packet_cmd == "ConnectionRefused" then
								self.connected = false
								local errs = packet.errors or {}
								local errStr = table.concat(errs, ", ")
								SM("Archipelago connection refused: " .. errStr)
							elseif packet_cmd == "PrintJSON" then
								local parts = packet.data or {}
								local message = ""
								for _, part in ipairs(parts) do
									if part.text then
										message = message .. part.text
									end
								end
								SM(message)
							elseif packet_cmd == "ReceivedItems" then
								local item_count = packet.items and #packet.items or 0
								local base_idx = packet["index"] or 0
								SM("Received " .. tostring(item_count) .. " items from server (index " .. tostring(base_idx) .. ")")
								if packet.items then
									if base_idx == 0 then
										AP_AllReceivedItems = {}
									end
									for i, item in ipairs(packet.items) do
										AP_AllReceivedItems[base_idx + i] = item
										local item_id = item.item
										local name = itemNames[item_id] or "Unknown Item"
										SM("Item: " .. name .. " (ID=" .. tostring(item_id) .. ", Location=" .. tostring(item.location) .. ", Player=" .. tostring(item.player) .. ")")
									end
									UpdatePlaylist()
								end
							else
								Trace("Received unhandled cmd: " .. tostring(packet_cmd))
							end
						end
					end
				end
			}
        end,
      }
  end

  return apHandler
end

CreateAPHandler()
apHandler:InitCommand()

local evaluation_trigger = Def.Actor{
	ModuleCommand=function(self)
		EvaluateCompletedSong()
	end
}

local modules = {}
modules["ScreenEvaluationNormal"] = evaluation_trigger
modules["ScreenEvaluationStage"] = evaluation_trigger
modules["ScreenEvaluationNonstop"] = evaluation_trigger

return modules
