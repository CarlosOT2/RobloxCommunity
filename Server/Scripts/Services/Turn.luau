-- Serviços
local ServerScriptService = game:GetService("ServerScriptService")
-- Módulos
local Turn = require(ServerScriptService.Systems.Modules.Turn)
local SessionData = require(ServerScriptService.Data.SessionData)

task.spawn(function()
	while task.wait(0.1) do
		for turnid, turnobj in pairs(Turn.Utils.GetAll()) do
			-- Verifica se pode finalizar o turno
			if Turn.Utils.CanEnd(turnid) then 
				Turn.End(turnid) 
			end
			
			-- Evento
			for _, entity in pairs(turnobj.entities) do
				Turn.Event.Fire(entity.char)
			end
		end
	end
end)
