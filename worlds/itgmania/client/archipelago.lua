-- Module configuration
local AP = {}

-- Constants. URL / Slot / Password need manual adjusting.
local HOST = "ws://localhost:38281"
local SLOT = "Player1"
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

GetAPHandlerInstance = function()
	return apHandlerInstance
end


local CreateRequest = function(event, data)
	return JsonEncode({
		event=event,
		data=data
	})
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
			SM("foobar")

			-- Connection time.
			self.socket = NETWORK:WebSocket{
            url=HOST,
            pingInterval=15,
            automaticReconnect=true,
            onMessage=function(msg)
				if msg.type == "WebSocketMessageType_Open" then
					self.connected = true
					SM("Connected to archipelago server at: ", HOST) 
				end
				if msg.type == "WebSocketMessageType_Message" then
					SM(msg.data)
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
