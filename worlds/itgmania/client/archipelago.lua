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
local seedName = "Unknown"
local AP_AllReceivedItems = {}

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

								itemNames = {}
								local count = 0
								if item_to_id then
									for name, id in pairs(item_to_id) do
										itemNames[id] = name
										count = count + 1
									end
								end
								SM("Loaded " .. tostring(count) .. " item names from DataPackage.")

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
