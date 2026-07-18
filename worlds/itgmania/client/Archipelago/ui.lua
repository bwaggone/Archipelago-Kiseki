-- ui.lua is the place where we create UI elements to support the archipelago
-- game.

local AP = ...

AP.MakePopupActor = function()
	return Def.ActorFrame {
		InitCommand = function(self)
			self:xy(-300, _screen.h - 100)
		end,
		APItemNotificationMessageCommand = function(self, params)
			table.insert(AP.notificationQueue, params)
			if not AP.isNotificationActive then
				self:queuecommand("ShowNext")
			end
		end,
		ShowNextCommand = function(self)
			if #AP.notificationQueue == 0 then
				AP.isNotificationActive = false
				return
			end
			
			AP.isNotificationActive = true
			local params = table.remove(AP.notificationQueue, 1)
			
			local text = ""
			local sub = ""
			local color_highlight = {1, 1, 1, 1}
			
			if params.type == "Received" then
				text = "RECEIVED"
				sub = AP.FormatNotificationName(params.name)
				color_highlight = {0.3, 0.9, 0.3, 1}
			elseif params.type == "Sent" then
				text = "CHECK SENT"
				sub = AP.FormatNotificationName(params.name)
				color_highlight = {0.3, 0.6, 0.9, 1}
			elseif params.type == "Connected" then
				text = "ARCHIPELAGO"
				sub = "CONNECTED: " .. tostring(params.name)
				color_highlight = {0.3, 0.9, 0.9, 1}
			elseif params.type == "Disconnected" then
				text = "ARCHIPELAGO"
				sub = "DISCONNECTED"
				color_highlight = {1, 0.3, 0.3, 1}
			end
			
			local label = self:GetChild("Title")
			local subtext = self:GetChild("Subtext")
			local strip = self:GetChild("AccentStrip")
			
			if label then
				label:settext(text)
				label:diffuse(color_highlight)
			end
			if subtext then
				subtext:settext(sub)
			end
			if strip then
				strip:diffuse(color_highlight)
			end
			
			self:finishtweening()
			self:linear(0.25):x(20)
			self:sleep(1.0)
			self:linear(0.25):x(-300)
			self:queuecommand("ShowNext")
		end,
		
		Def.Quad {
			Name = "Background",
			InitCommand = function(self)
				self:zoomto(260, 48)
				self:halign(0):valign(0)
				self:diffuse(0, 0, 0, 0.8)
			end
		},
		Def.Quad {
			Name = "AccentStrip",
			InitCommand = function(self)
				self:zoomto(4, 48)
				self:halign(0):valign(0)
				self:diffuse(1, 1, 1, 1)
			end
		},
		LoadFont("Common Bold") .. {
			Name = "Title",
			InitCommand = function(self)
				self:xy(12, 4)
				self:halign(0):valign(0)
				self:zoom(0.6)
			end
		},
		LoadFont("Common Normal") .. {
			Name = "Subtext",
			InitCommand = function(self)
				self:xy(12, 32)
				self:halign(0):valign(0)
				self:zoom(0.5)
				self:maxwidth(240)
			end
		}
	}
end

-- Helper function to get all unlocked songs / charts from received items.
-- Unlocked songs are defined as received items containing a "/" character in their name.
local function getUnlockedSongs()
	local songs = {}
	local seen = {}
	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name and name:find("/") and not seen[name] then
				seen[name] = true
				table.insert(songs, name)
			end
		end
	end
	-- Sort alphabetically for better navigation
	table.sort(songs)
	return songs
end

-- Helper to count checks (completed and total) for a specific chart name.
-- Iterates over all possible locations in the DataPackage matching "chart_name .. '-'"
-- and cross-references them with the cached checked locations.
local function getChecksForSong(chart_name)
	local total = 0
	local completed = 0
	if AP.locationIds then
		for name, id in pairs(AP.locationIds) do
			if name:sub(1, #chart_name + 1) == chart_name .. "-" then
				total = total + 1
				if AP.checkedLocations and AP.checkedLocations[id] then
					completed = completed + 1
				end
			end
		end
	end
	return completed, total
end

-- Helper to get stats on unlocked Archipelago modifiers.
-- Traverses received items to determine:
-- 1. Highest BPM speed limit modifier item (e.g. "Speed 550bpm")
-- 2. Darkest background filter modifier item (e.g. "Darker Filter")
-- 3. Number of "Bonus Percentage" items received
local function getModifierStats()
	local max_bpm = "250 BPM"
	local max_filter = "None"
	local bonus_count = 0

	local speed_items = {
		["Speed 350bpm"] = 350,
		["Speed 450bpm"] = 450,
		["Speed 550bpm"] = 550,
		["Speed 650bpm"] = 650,
		["Speed 750bpm"] = 750,
		["Speed Any BPM"] = 9999,
	}

	local filter_items = {
		["Dark Filter"] = 1,
		["Darker Filter"] = 2,
		["Darkest Filter"] = 3,
	}

	local highest_speed_val = 0
	local highest_filter_val = 0

	if AP.AP_AllReceivedItems then
		for _, item in ipairs(AP.AP_AllReceivedItems) do
			local name = AP.itemNames[item.item]
			if name then
				if name == "Bonus Percentage" then
					bonus_count = bonus_count + 1
				elseif speed_items[name] then
					if speed_items[name] > highest_speed_val then
						highest_speed_val = speed_items[name]
						if name == "Speed Any BPM" then
							max_bpm = "Unlimited"
						else
							max_bpm = name:gsub("Speed ", ""):upper()
						end
					end
				elseif filter_items[name] then
					if filter_items[name] > highest_filter_val then
						highest_filter_val = filter_items[name]
						max_filter = name:gsub(" Filter", "")
					end
				end
			end
		end
	end

	return max_bpm, max_filter, bonus_count
end

AP.MakeStatusOverlayActor = function()
	local status_overlay_actor = nil
	local scrollOffset = 1
	local overlay_visible = false
	local inputCallback = nil
	
	local paneWidth = 580
	local paneHeight = 440
	local RowHeight = 26
	
	-- Helper to update all visible UI components in the overlay
	local function updateOverlayUI(self)
		local backdrop = self:GetChild("Backdrop")
		local container = self:GetChild("Container")
		
		backdrop:visible(overlay_visible)
		container:visible(overlay_visible)
		
		if not overlay_visible then return end
		
		local apHandler = GetAPHandlerInstance()
		if not apHandler or not apHandler.connected then
			container:GetChild("ConnectedGroup"):visible(false)
			container:GetChild("OfflineMsg"):visible(true)
			return
		end
		
		container:GetChild("ConnectedGroup"):visible(true)
		container:GetChild("OfflineMsg"):visible(false)
		
		-- Update metadata: Room and Seed names
		local room_str = "Room: " .. tostring(AP.SLOT)
		local seed_str = "Seed: " .. tostring(AP.seedName)
		container:GetChild("ConnectedGroup"):GetChild("RoomSeedText"):settext(room_str .. "    |    " .. seed_str)
		
		-- Update goal progress numbers
		local completed_checks = 0
		if AP.checkedLocations then
			for _ in pairs(AP.checkedLocations) do
				completed_checks = completed_checks + 1
			end
		end
		local target_checks = AP.slotOptions.win_count or 15
		local progress_pct = math.min(1.0, completed_checks / math.max(1, target_checks))
		
		local progress_text = string.format("AP Goal Progress: %d / %d checks (%.1f%%)", completed_checks, target_checks, progress_pct * 100)
		container:GetChild("ConnectedGroup"):GetChild("ProgressText"):settext(progress_text)
		
		-- Update progress bar quad width
		local bar_fg = container:GetChild("ConnectedGroup"):GetChild("ProgressBarFG")
		bar_fg:zoomto(500 * progress_pct, 12)
		
		-- Update modifier stats line
		local max_bpm, max_filter, bonus_count = getModifierStats()
		local mod_text = string.format("Max Speed: %s    |    BG Filter: %s    |    Bonus Percentage Items: %d", max_bpm, max_filter, bonus_count)
		container:GetChild("ConnectedGroup"):GetChild("ModifierText"):settext(mod_text)
		
		-- Update scrollable songs list rows
		local songs = getUnlockedSongs()
		local list_af = container:GetChild("ConnectedGroup"):GetChild("SongList")
		
		for i = 1, 10 do
			local row = list_af:GetChild("Row" .. i)
			local idx = scrollOffset + i - 1
			if idx <= #songs then
				local song_name = songs[idx]
				local comp, tot = getChecksForSong(song_name)
				
				-- Trim filename to show only the folder path
				local display_name = song_name:match("^(.-)/[^/]+$") or song_name
				row:GetChild("Name"):settext(idx .. ". " .. display_name)
				row:GetChild("Checks"):settext(string.format("[ %d / %d ]", comp, tot))
				
				-- Diffuse color based on completion percentage (green if finished)
				if comp == tot and tot > 0 then
					row:GetChild("Checks"):diffuse(0.3, 1.0, 0.3, 1) -- completed green
				else
					row:GetChild("Checks"):diffuse(1.0, 1.0, 1.0, 1) -- normal white
				end
				row:visible(true)
			else
				row:visible(false)
			end
		end
	end

	-- Custom overlay input callback. Consumes all inputs when overlay is active
	local function input(event)
		if not overlay_visible then return false end
		
		if not (event and event.PlayerNumber and event.button) then
			return false
		end
		
		if event.type ~= "InputEventType_FirstPress" then
			return false
		end
		
		local key = event.DeviceInput.button
		local game_btn = event.GameButton
		
		local songs = getUnlockedSongs()
		local num_songs = #songs
		
		if game_btn == "MenuDown" or key == "DeviceButton_down" then
			-- Scroll down
			if num_songs > 10 then
				scrollOffset = math.min(scrollOffset + 1, num_songs - 10 + 1)
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
		elseif game_btn == "MenuUp" or key == "DeviceButton_up" then
			-- Scroll up
			if scrollOffset > 1 then
				scrollOffset = math.max(1, scrollOffset - 1)
				SOUND:PlayOnce(THEME:GetPathS("ScreenSelectMaster", "change"))
				MESSAGEMAN:Broadcast("APStatusRefresh")
			end
		elseif game_btn == "Start" or game_btn == "Back" or game_btn == "Select" or key == "DeviceButton_F10" or key == "DeviceButton_escape" then
			-- Toggle overlay off
			overlay_visible = false
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			if inputCallback then
				local screen = SCREENMAN:GetTopScreen()
				if screen then
					screen:RemoveInputCallback(inputCallback)
				end
				inputCallback = nil
			end
			MESSAGEMAN:Broadcast("APStatusRefresh")
		end
		
		return true -- consume input
	end

	-- Toggle overlay active state, routing player input and registering the input listener
	local function toggleOverlay(self)
		overlay_visible = not overlay_visible
		scrollOffset = 1
		
		local screen = SCREENMAN:GetTopScreen()
		if overlay_visible then
			SOUND:PlayOnce(THEME:GetPathS("Common", "Start"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, true)
			end
			
			inputCallback = input
			screen:AddInputCallback(inputCallback)
		else
			SOUND:PlayOnce(THEME:GetPathS("Common", "Cancel"))
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			if inputCallback then
				screen:RemoveInputCallback(inputCallback)
				inputCallback = nil
			end
		end
		
		self:playcommand("Refresh")
	end

	-- Persistent listener registered at screen boot to capture F10 toggle presses
	local function F10_listener(event)
		if event.type == "InputEventType_FirstPress" and event.DeviceInput.button == "DeviceButton_F10" then
			if status_overlay_actor then
				status_overlay_actor:playcommand("ToggleOverlay")
			end
			return true
		end
		return false
	end
	
	-- Pre-generate the table list row actors (Def.ActorFrame doesn't support C++ methods during file parsing)
	local song_list_children = {}
	for i = 1, 10 do
		song_list_children[#song_list_children+1] = Def.ActorFrame {
			Name = "Row" .. i,
			InitCommand = function(self)
				self:y((i - 1) * RowHeight - 65)
			end,
			
			-- Left column: Song Folder name
			LoadFont("Common Normal") .. {
				Name = "Name",
				Text = "",
				InitCommand = function(self)
					self:x(-paneWidth/2 + 30):halign(0):zoom(0.5):maxwidth(420)
				end
			},
			-- Right column: Completion status counters
			LoadFont("Common Normal") .. {
				Name = "Checks",
				Text = "",
				InitCommand = function(self)
					self:x(paneWidth/2 - 30):halign(1):zoom(0.5)
				end
			}
		}
	end

	local af = Def.ActorFrame {
		Name = "APStatusOverlayMain",
		InitCommand = function(self)
			status_overlay_actor = self
			overlay_visible = false
			scrollOffset = 1
		end,
		ModuleCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen then
				screen:AddInputCallback(F10_listener)
			end
		end,
		OffCommand = function(self)
			local screen = SCREENMAN:GetTopScreen()
			if screen and F10_listener then
				screen:RemoveInputCallback(F10_listener)
			end
			if inputCallback and screen then
				screen:RemoveInputCallback(inputCallback)
				inputCallback = nil
			end
			for player in ivalues(PlayerNumber) do
				SCREENMAN:set_input_redirected(player, false)
			end
			overlay_visible = false
		end,
		
		ToggleOverlayCommand = function(self)
			toggleOverlay(self)
		end,
		
		APStatusRefreshMessageCommand = function(self)
			self:playcommand("Refresh")
		end,
		
		RefreshCommand = function(self)
			updateOverlayUI(self)
		end,
		
		-- Fullscreen semi-transparent backdrop to dim the background music wheel
		Def.Quad {
			Name = "Backdrop",
			InitCommand = function(self)
				self:FullScreen():diffuse(0,0,0,0.85):visible(false)
			end
		},
		
		-- Center container dialog panel
		Def.ActorFrame {
			Name = "Container",
			InitCommand = function(self)
				self:xy(_screen.cx, _screen.cy):visible(false)
			end,
			
			-- White outer border box
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth + 4, paneHeight + 4):diffuse(Color.White)
				end
			},
			-- Main black background body
			Def.Quad {
				InitCommand = function(self)
					self:zoomto(paneWidth, paneHeight):diffuse(Color.Black)
				end
			},
			
			-- Top header background strip
			Def.Quad {
				InitCommand = function(self)
					self:y(-paneHeight/2 + 25):zoomto(paneWidth, 50):diffuse(0.12, 0.12, 0.12, 1)
				end
			},
			
			-- Header title text
			LoadFont("Common Bold") .. {
				Text = "ARCHIPELAGO STATUS",
				InitCommand = function(self)
					self:y(-paneHeight/2 + 18):zoom(0.7):diffuse(0.3, 0.9, 0.9, 1)
				end
			},
			
			-- Bottom footer instructional text
			LoadFont("Common Normal") .. {
				Text = "Use MENUUP/MENUDOWN or arrow keys to scroll. Press F10 or ESC to exit.",
				InitCommand = function(self)
					self:y(paneHeight/2 - 18):zoom(0.55):diffuse(0.7, 0.7, 0.7, 1)
				end
			},
			
			-- Offline warning message (only visible if the WebSocket client is disconnected)
			LoadFont("Common Normal") .. {
				Name = "OfflineMsg",
				Text = "Not connected to Archipelago server.",
				InitCommand = function(self)
					self:zoom(0.85):diffuse(1, 0.3, 0.3, 1):visible(true)
				end
			},
			
			-- Container for all statistics and song lists shown when connected
			Def.ActorFrame {
				Name = "ConnectedGroup",
				InitCommand = function(self)
					self:visible(false)
				end,
				
				-- Connection metadata: Room name and Seed name
				LoadFont("Common Normal") .. {
					Name = "RoomSeedText",
					Text = "",
					InitCommand = function(self)
						self:y(-paneHeight/2 + 40):zoom(0.5):diffuse(0.8, 0.8, 0.8, 1)
					end
				},
				
				-- AP Goal Progress count text (e.g. "AP Goal Progress: 10 / 15 checks")
				LoadFont("Common Bold") .. {
					Name = "ProgressText",
					Text = "",
					InitCommand = function(self)
						self:y(-148):zoom(0.6):diffuse(1, 1, 1, 1)
					end
				},
				
				-- Progress bar background border
				Def.Quad {
					Name = "ProgressBarBG",
					InitCommand = function(self)
						self:y(-124):zoomto(502, 14):diffuse(0.3, 0.3, 0.3, 1)
					end
				},
				-- Progress bar inner background fill (dark track)
				Def.Quad {
					InitCommand = function(self)
						self:y(-124):zoomto(500, 12):diffuse(0.08, 0.08, 0.08, 1)
					end
				},
				-- Progress bar active foreground fill (green fill)
				Def.Quad {
					Name = "ProgressBarFG",
					InitCommand = function(self)
						self:y(-124):halign(0):x(-250):zoomto(0, 12):diffuse(0.3, 0.8, 0.3, 1)
					end
				},
				
				-- Active Archipelago modifiers row: Max BPM speed limit, BG filter, and Bonus items
				LoadFont("Common Normal") .. {
					Name = "ModifierText",
					Text = "",
					InitCommand = function(self)
						self:y(-102):zoom(0.52):diffuse(0.9, 0.9, 0.4, 1)
					end
				},
				
				-- Thin divider line separating metadata from song list
				Def.Quad {
					InitCommand = function(self)
						self:y(-90):zoomto(paneWidth - 40, 2):diffuse(0.4, 0.4, 0.4, 1)
					end
				},
				
				-- Left column header (Unlocked Song / Chart)
				LoadFont("Common Bold") .. {
					Text = "Unlocked Song / Chart",
					InitCommand = function(self)
						self:y(-74):x(-paneWidth/2 + 30):halign(0):zoom(0.5):diffuse(0.6, 0.6, 0.6, 1)
					end
				},
				-- Right column header (Checks Completed)
				LoadFont("Common Bold") .. {
					Text = "Checks Completed",
					InitCommand = function(self)
						self:y(-74):x(paneWidth/2 - 30):halign(1):zoom(0.5):diffuse(0.6, 0.6, 0.6, 1)
					end
				},
				
				-- ActorFrame holding the list of scrollable song rows
				Def.ActorFrame {
					Name = "SongList",
					InitCommand = function(self)
						self:y(10)
					end,
					unpack(song_list_children)
				}
			}
		}
	}
	
	return af
end

AP.MakeScreenActor = function(screenName)
	local af = Def.ActorFrame {
		AP.MakePopupActor(),
	}
	
	if screenName == "ScreenSelectMusic" then
		af[#af+1] = AP.MakeStatusOverlayActor()
	end
	
	if screenName:find("ScreenEvaluation") then
		af[#af+1] = Def.Actor {
			ModuleCommand = function(self)
				AP.EvaluateCompletedSong()
			end
		}
	end
	
	return af
end
