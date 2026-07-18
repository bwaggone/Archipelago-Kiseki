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

AP.MakeScreenActor = function(screenName)
	local af = Def.ActorFrame {
		AP.MakePopupActor(),
	}
	
	if screenName:find("ScreenEvaluation") then
		af[#af+1] = Def.Actor {
			ModuleCommand = function(self)
				AP.EvaluateCompletedSong()
			end
		}
	end
	
	return af
end
