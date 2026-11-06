-- Serviços
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService('ServerScriptService')
-- RE
local MovimentationEvent = ReplicatedStorage.RE:WaitForChild("Movimentation")
-- Módulos
local SessionData = require(ServerScriptService.Data.SessionData)
local WorldCell = require(ServerScriptService.Systems.Modules.World.WorldCell)
local Navigation = require(ServerScriptService.Systems.Modules.World.Navigation)
local Cooldown = require(ServerScriptService.Systems.Modules.Stats.Cooldown)
local INFO = require(ServerScriptService.Systems.Modules.INFO).Character.Movimentation

function WalkTo(instance: Model | Player, position: Vector3): boolean?
	local data = SessionData.Entity.Get(instance)
	if not data then return end
	if not data.references.char then return end
	if Cooldown.IsOnCooldown(instance, INFO.CDName) then return end 

	if data.temp.dialogue.active then return end
	if typeof(position) ~= "Vector3" then return end

	
	local path = Navigation.FindPath(WorldCell.GetCellFloorFromWorkspace(data.temp.worldcell.currentCell), data.references.char:GetPivot().Position, position)
	if not path then return false end
	
	if data.references.player then
		MovimentationEvent:FireClient(
			data.references.player, 
			data.references.char, 
			"Indicator", 
			position
		) 
	end
	
	MovimentationEvent:FireAllClients(data.references.char, "Start") 
	
	local char = data.references.char
	local hum = char:FindFirstChildOfClass("Humanoid")

	local pivot = char:GetPivot()
	local offset = Vector3.new(0, pivot.Position.Y - path[1].position.Y, 0)
	
	local rotation = pivot.Rotation
	
	Cooldown.Add(char, INFO.CDName, INFO.CDDuration)
	
	data.temp.movimentation.id += 1
	local movementId = data.temp.movimentation.id
	for i, node in path do
		if i == 1 then continue end
		
		local start = char:GetPivot().Position
		local target = node.position + offset
		local direction = (target - start) * Vector3.new(1, 0, 1)
		local targetRotation = rotation

		if direction.Magnitude > 0.001 then
			targetRotation = CFrame.lookAt(Vector3.zero, direction).Rotation
		end

		local duration = (target - start).Magnitude / hum.WalkSpeed
		local elapsed = 0

		while elapsed < duration do
			local dt = RunService.Heartbeat:Wait()
			if movementId ~= data.temp.movimentation.id then
				return true 
			end
			elapsed += dt
			rotation = rotation:Lerp(targetRotation, 1 - math.exp(-INFO.rotationSpeed * dt))

			local position = start:Lerp(target, math.min(elapsed / duration, 1))
			char:PivotTo(CFrame.new(position) * rotation)
		end
	end

	MovimentationEvent:FireAllClients(data.references.char, "Stop") 
	
	return true
end

return {
	WalkTo = WalkTo
}