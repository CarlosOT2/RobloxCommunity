-- Serviços
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService('ServerScriptService')
-- Módulos
local SessionData = require(ServerScriptService.Data.SessionData)
local Turn = require(ServerScriptService.Systems.Modules.Turn)
local Movimentation = require(ServerScriptService.Systems.Modules.Actions.Handlers.Movimentation)
local Dialogue = require(ServerScriptService.Systems.Modules.Actions.Handlers.Dialogue)

local handlers = { 
	["Movimentation"] = Movimentation, 
	["Dialogue"] = Dialogue 
}

function Execute(instance: Model | Player, handler: string, action: string, ...)
	local data = SessionData.Entity.Get(instance)
	if not data then return end
	if not data.references.char then return end 

	local module = handlers[handler]
	if not module then
		warn("Action.Execute(): handler inválido:", handler)
		return
	end
	local execute = module[action]
	if typeof(execute) ~= "function" then
		warn("Action.Execute(): ação inválida:", action)
		return
	end
	
	local char = data.references.char
	local turnid = Turn.Utils.GetEntityTurnId(char)
	if turnid then
		if not Turn.Utils.IsEntityTurn(char) then return end
		if Turn.State.Get(turnid) ~= "awaitinginput" then return end
		
		task.spawn(function(...)
			Turn.State.Set(turnid, "resolving")

			local success = execute(instance, ...)
			if not success then 
				Turn.State.Set(turnid, "awaitinginput")
				return 
			end

			Turn.State.Set(turnid, "awaitinginput")
			Turn.Order.Next(turnid)
		end, ...)
	else 

		return execute(instance, ...)
	end
end

return {
	Execute = Execute
}