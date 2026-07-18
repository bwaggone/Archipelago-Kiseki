local AP = ...

AP.CreateAPHandler = function() 
  if AP.apHandler == nil then
    AP.apHandler = Def.ActorFrame{
      Name="ArchipelagoHandler",
		InitCommand=function(self)
			AP.apHandlerInstance = self
			AP.apHandlerShuttingDown = false
			self.socket = nil
			self.connected = false
			self.errorMsg = nil

			AP.AP_SM("Connecting to Archipelago server at: " .. AP.HOST)

			-- Connection time.
			self.socket = NETWORK:WebSocket{
				url=AP.HOST,
				pingInterval=15,
				automaticReconnect=true,
				onMessage=function(msg)
					AP.HandleMessage(self, msg)
				end
			}
        end,
      }
  end

  return AP.apHandler
end
