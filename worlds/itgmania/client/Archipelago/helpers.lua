local AP = ...

AP.FormatNotificationName = function(name)
	if not name then return "Unknown" end
	if name:find("/") then
		local parts = {}
		for part in name:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		if #parts >= 2 then
			return parts[2]
		elseif #parts == 1 then
			return parts[1]
		end
	end
	return name
end

AP.CreateRequest = function(event, data)
	return JsonEncode({
		event=event,
		data=data
	})
end

-- Helper function to get all unlocked songs / charts from received items.
-- Unlocked songs are defined as received items containing a "/" character in their name.
AP.GetUnlockedSongs = function()
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

AP.GetChecksForSong = function(chart_name)
	local total = 0
	local completed = 0
	if AP.locationIds then
		for name, id in pairs(AP.locationIds) do
			if name:sub(1, #chart_name + 1) == chart_name .. "-" then
				-- If activeLocationIds is populated, only count active locations.
				-- Otherwise, fall back to counting all defined locations.
				if not AP.activeLocationIds or AP.activeLocationIds[id] then
					total = total + 1
					if AP.checkedLocations and AP.checkedLocations[id] then
						completed = completed + 1
					end
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
AP.GetModifierStats = function()
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
