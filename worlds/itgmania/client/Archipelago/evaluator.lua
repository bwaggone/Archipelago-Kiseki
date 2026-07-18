local AP = ...

AP.EvaluateCompletedSong = function()
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
	local chart_name = AP.folderToChartName[folderName]
	if not chart_name then
		-- Not an AP song, ignore silently
		return
	end
	
	AP.AP_SM("Evaluating completed AP song: " .. chart_name)
	
	local checks_to_send = {}
	local queue_check = function(suffix)
		local loc_name = chart_name .. "-" .. suffix
		local loc_id = AP.locationIds[loc_name]
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
				AP.Trace("Archipelago warning: CalculateExScore function not found in global scope!")
			end
			
			-- Select score percentage based on option
			local activePercent = moneyPercent
			local score_system_name = "Money"
			if AP.slotOptions.score_type == 1 then
				activePercent = exPercent
				score_system_name = "EX"
			elseif AP.slotOptions.score_type == 2 then
				activePercent = highExPercent
				score_system_name = "High EX (FA+)"
			end
			
			AP.AP_SM("Player " .. ToEnumShortString(pn) .. " Performance - " .. score_system_name .. " Score: " .. string.format("%.2f", activePercent) .. "% (Money: " .. string.format("%.2f", moneyPercent) .. "%" .. (CalculateExScore and (", EX: " .. string.format("%.2f", exPercent) .. "%") or "") .. "), Failed: " .. tostring(is_failed))
			
			-- Check clear condition
			local fail_allowed = (AP.slotOptions.fail_allowed == true or AP.slotOptions.fail_allowed == 1)
			local passed_clear = false
			if not is_failed or fail_allowed then
				if activePercent >= AP.slotOptions.passing_score then
					passed_clear = true
				end
			end
			
			if passed_clear then
				AP.AP_SM("Player " .. ToEnumShortString(pn) .. " CLEARED the song logic!")
				queue_check("0")
				queue_check("1")
				
				-- Check score thresholds
				if activePercent >= 85 then queue_check("85") end
				if activePercent >= 90 then queue_check("90") end
				if activePercent >= 96 then queue_check("96") end
				if activePercent >= 98 then queue_check("98") end
				if activePercent >= 99 then queue_check("99") end
			else
				AP.AP_SM("Player " .. ToEnumShortString(pn) .. " did not clear the song logic (Passing Score target: " .. tostring(AP.slotOptions.passing_score) .. "%)")
			end
			
			-- Quad and Quint are independent of the selected score_type
			if moneyPercent >= 100 then
				AP.AP_SM("Player " .. ToEnumShortString(pn) .. " got a QUAD money score!")
				queue_check("quad")
			end
			if exPercent >= 100 and CalculateExScore then
				AP.AP_SM("Player " .. ToEnumShortString(pn) .. " got a QUINT EX score!")
				queue_check("quint")
			end
		end
	end
	
	if #checks_to_send > 0 and AP.apHandlerInstance and AP.apHandlerInstance.connected and AP.apHandlerInstance.socket then
		AP.AP_SM("Sending " .. tostring(#checks_to_send) .. " location checks to server...")
		local checks_packet = {
			["cmd"] = "LocationChecks",
			locations = checks_to_send
		}
		local payload = JsonEncode({ checks_packet })
		AP.apHandlerInstance.socket:Send(payload, false)
		MESSAGEMAN:Broadcast("APItemNotification", { type = "Sent", name = chart_name })
	else
		AP.AP_SM("No locations to check or client is not connected.")
	end
end
