local AP = ...

AP.HandleMessage = function(self, msg)
	if msg.type == "WebSocketMessageType_Open" then
		AP.AP_SM("WebSocket transport connected. Waiting for RoomInfo...")
	elseif msg.type == "WebSocketMessageType_Close" then
		self.connected = false
		AP.initialSyncComplete = false
		AP.AP_SM("Archipelago connection closed: " .. tostring(msg.reason))
		MESSAGEMAN:Broadcast("APItemNotification", { type = "Disconnected" })
	elseif msg.type == "WebSocketMessageType_Error" then
		self.connected = false
		AP.initialSyncComplete = false
		AP.AP_SM("Archipelago connection error: " .. tostring(msg.reason))
		MESSAGEMAN:Broadcast("APItemNotification", { type = "Disconnected" })
	elseif msg.type == "WebSocketMessageType_Message" then
		local success, packets = pcall(JsonDecode, msg.data)
		if not success then
			AP.AP_SM("Failed to decode JSON from Archipelago server: " .. tostring(msg.data))
			return
		end

		for _, packet in ipairs(packets) do
			local packet_cmd = packet["cmd"]
			if packet_cmd == "RoomInfo" then
				AP.seedName = packet["seed_name"] or "Unknown"
				AP.AP_SM("Received RoomInfo (Seed: " .. AP.seedName .. "). Requesting DataPackage...")
				local get_dp_packet = {
					["cmd"] = "GetDataPackage",
					games = { AP.GAME_NAME }
				}
				local payload = JsonEncode({ get_dp_packet })
				self.socket:Send(payload, false)
			elseif packet_cmd == "DataPackage" then
				local games = packet.data and packet.data.games
				local game_data = games and games[AP.GAME_NAME]
				local item_to_id = game_data and game_data.item_name_to_id
				local location_to_id = game_data and game_data.location_name_to_id

				AP.itemNames = {}
				local count = 0
				if item_to_id then
					for name, id in pairs(item_to_id) do
						AP.itemNames[id] = name
						count = count + 1
					end
				end

				AP.locationIds = {}
				AP.folderToChartName = {}
				local loc_count = 0
				local cached_folders = 0
				if location_to_id then
					for name, id in pairs(location_to_id) do
						AP.locationIds[name] = id
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
								AP.folderToChartName[folderName] = base_chart
								cached_folders = cached_folders + 1
							end
						end
					end
				end
				AP.AP_SM("Loaded " .. tostring(count) .. " item names, " .. tostring(loc_count) .. " locations, and " .. tostring(cached_folders) .. " folder mappings from DataPackage.")

				AP.AP_SM("Sending Connect packet...")
				local connect_packet = {
					["cmd"] = "Connect",
					game = AP.GAME_NAME,
					name = AP.SLOT,
					uuid = "itgmania-ap-client-uuid",
					version = { major = 0, minor = 6, build = 8, ["class"] = "Version" },
					items_handling = 7, -- Receive all items (remote, own, starting)
					password = AP.PASSWORD,
					tags = {},
					slot_data = true
				}
				local connect_payload = JsonEncode({ connect_packet })
				self.socket:Send(connect_payload, false)
			elseif packet_cmd == "Connected" then
				self.connected = true
				AP.initialSyncComplete = false
				AP.AP_SM("Successfully connected to Archipelago! Slot: " .. tostring(packet.slot))
				MESSAGEMAN:Broadcast("APItemNotification", { type = "Connected", name = packet.slot })
				if packet["slot_data"] then
					AP.slotOptions.score_type = packet["slot_data"]["score_type"] or 1
					AP.slotOptions.passing_score = packet["slot_data"]["passing_score"] or 0
					AP.slotOptions.fail_allowed = packet["slot_data"]["fail_allowed"]
					AP.AP_SM("Slot Options - Score Type: " .. tostring(AP.slotOptions.score_type) .. 
					   ", Passing Score: " .. tostring(AP.slotOptions.passing_score) .. 
					   ", Fail Allowed: " .. tostring(AP.slotOptions.fail_allowed))
				end
			elseif packet_cmd == "RoomUpdate" then
				AP.AP_SM("Received RoomUpdate from server.")
				if packet["slot_data"] then
					AP.slotOptions.score_type = packet["slot_data"]["score_type"] or AP.slotOptions.score_type
					AP.slotOptions.passing_score = packet["slot_data"]["passing_score"] or AP.slotOptions.passing_score
					AP.slotOptions.fail_allowed = packet["slot_data"]["fail_allowed"] or AP.slotOptions.fail_allowed
					AP.AP_SM("Updated Slot Options - Score Type: " .. tostring(AP.slotOptions.score_type) .. 
					   ", Passing Score: " .. tostring(AP.slotOptions.passing_score) .. 
					   ", Fail Allowed: " .. tostring(AP.slotOptions.fail_allowed))
				end
			elseif packet_cmd == "ConnectionRefused" then
				self.connected = false
				local errs = packet.errors or {}
				local errStr = table.concat(errs, ", ")
				AP.AP_SM("Archipelago connection refused: " .. errStr)
			elseif packet_cmd == "PrintJSON" then
				local parts = packet.data or {}
				local message = ""
				for _, part in ipairs(parts) do
					if part.text then
						message = message .. part.text
					end
				end
				AP.AP_SM(message)
			elseif packet_cmd == "ReceivedItems" then
				local item_count = packet.items and #packet.items or 0
				local base_idx = packet["index"] or 0
				AP.AP_SM("Received " .. tostring(item_count) .. " items from server (index " .. tostring(base_idx) .. ")")
				if packet.items then
					local isNewItem = self.connected and AP.initialSyncComplete
					if base_idx == 0 then
						AP.AP_AllReceivedItems = {}
					end
					for i, item in ipairs(packet.items) do
						AP.AP_AllReceivedItems[base_idx + i] = item
						local item_id = item.item
						local name = AP.itemNames[item_id] or "Unknown Item"
						if name:find("/") then
							AP.AP_SM("Received Song: " .. name .. " (ID=" .. tostring(item_id) .. ", Location=" .. tostring(item.location) .. ", Player=" .. tostring(item.player) .. ")")
						else
							AP.AP_SM("Received Mod/Filler (Non-Song): " .. name .. " (ID=" .. tostring(item_id) .. ", Location=" .. tostring(item.location) .. ", Player=" .. tostring(item.player) .. ")")
						end
						if isNewItem then
							MESSAGEMAN:Broadcast("APItemNotification", { type = "Received", name = name })
						end
					end
					AP.initialSyncComplete = true
					AP.UpdatePlaylist()
				end
			else
				AP.Trace("Received unhandled cmd: " .. tostring(packet_cmd))
			end
		end
	end
end
