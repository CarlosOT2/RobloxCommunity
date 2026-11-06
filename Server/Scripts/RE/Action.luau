-- Serviços
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService('ServerScriptService')
-- RE
local ActionEvent = ReplicatedStorage.RE:WaitForChild("Action")
-- Módulos
local Action = require(ServerScriptService.Systems.Modules.Actions.Action)

ActionEvent.OnServerEvent:Connect(function(player: Player, handler: string, action: string, ...)
	Action.Execute(player, handler, action, ...)
end)