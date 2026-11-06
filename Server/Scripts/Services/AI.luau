-- Serviços
local ServerScriptService = game:GetService("ServerScriptService")
-- Módulos
local SessionData = require(ServerScriptService.Data.SessionData)
local AIController = require(ServerScriptService.Systems.Modules.AIController)

task.spawn(function()
	while task.wait(0.25) do
		for name, data in pairs(SessionData.Entity.GetAll()) do	
			if data.type ~= "npc" then continue end
			if not data.references.char then continue end 
			
			AIController.DetectAheadForCombat(data.references.char)
			AIController.ExecuteTurn(data.references.char)
		end
	end
end)