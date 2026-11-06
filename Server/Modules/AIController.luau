-- Serviços
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
-- Módulos
local SessionData = require(ServerScriptService.Data.SessionData)
local Action = require(ServerScriptService.Systems.Modules.Actions.Action)
local Turn = require(ServerScriptService.Systems.Modules.Turn)
local WorldCell = require(ServerScriptService.Systems.Modules.World.WorldCell)
local Navigation = require(ServerScriptService.Systems.Modules.World.Navigation)

local TypesTurn = require(ReplicatedStorage.Types.Turn)

local INFO = require(ServerScriptService.Systems.Modules.INFO)


---------------------------------------------------------
-- Funções Locais
local function Visual(size: Vector3, cframe: CFrame)
	local hitbox: Part = Instance.new("Part")
	hitbox.Anchored = true
	hitbox.Material = Enum.Material.Plastic
	hitbox.Color = Color3.new(1, 0, 0)
	hitbox.CanCollide = false
	hitbox.CastShadow = false
	hitbox.Transparency = 0.5
	hitbox.Massless = true
	hitbox.Size = size

	hitbox.Parent = workspace
	hitbox.CFrame = cframe

	task.delay(0.2, function()
		hitbox:Destroy()
	end)
end
local function GetEntitiesFromParts(parts: { BasePart }): { char: Model }
	local entities: { Model } = {}
	local added = {} -- cache para evitar duplicados

	for _, part in ipairs(parts) do
		local char = part.Parent
		if not char then continue end
		if not char:IsA("Model") then continue end
		if not char:FindFirstChild("Humanoid") then continue end
		if not char:FindFirstChild("HumanoidRootPart") then continue end

		-- evita adicionar o mesmo character mais de uma vez
		if added[char] then continue end
		added[char] = true

		table.insert(entities, char)
	end

	return entities
end
local function DetectPartsAhead(instance: Player | Model): { BasePart }?
	local data = SessionData.Entity.Get(instance)
	if not data then return end 
	if not data.references.char then return end 
	
	local char = data.references.char
	local hrp: Part = char:WaitForChild("HumanoidRootPart") :: Part

	local size = INFO.Entities.Detection.size

	local cframe = hrp.CFrame * CFrame.new(0, 0, -( size.Z / 2 + 2))

	-- Params
	local params: OverlapParams = OverlapParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Visual(size, cframe)
	return workspace:GetPartBoundsInBox(cframe, size, params)
end
local function DetectEntitiesAhead(char: Model)
	local parts = DetectPartsAhead(char)
	if not parts or #parts <= 0 then return end 

	local data = SessionData.Entity.Get(char)
	if not data then return end 

	local entities = GetEntitiesFromParts(parts)
	if not entities or next(entities) == nil then return end

	return entities
end

local function GetClosestEntityId(char: Model, entities: TypesTurn.entities): TypesTurn.entityid?
	local origin = char:GetPivot().Position
	local closest: TypesTurn.entityid? = nil
	local closestDistance = math.huge

	for _, entity in pairs(entities) do
		local distance = (entity.char:GetPivot().Position - origin).Magnitude

		if distance < closestDistance then
			closestDistance = distance
			closest = entity.entityid
		end
	end

	return closest
end

---------------------------------------------------------
-- Funções Módulo
function DetectAheadForCombat(char: Model)
	local entities = DetectEntitiesAhead(char)
	if not entities then return end
	
	local entitiesWithSelf = { char, table.unpack(entities) }
	if not Turn.Utils.CanStart(entitiesWithSelf) then return end 
	
	local data = SessionData.Entity.Get(char)
	if not data then return end

	if not Turn.Utils.IsEntityInTurn(char) then
		local turnentities = {}
		
		for _, char in pairs(entitiesWithSelf) do
			table.insert(turnentities, { char = char })
		end
		
		Turn.Start(turnentities)
	else
		local turnid = Turn.Utils.GetEntityTurnId(char)
		if not turnid then return end

		for _, char in pairs(entities) do
			if Turn.Utils.IsEntityInTurn(char) then continue end
			Turn.Entity.Add(char, turnid)
		end
	end
end
function ExecuteTurn(char: Model)
	local data = SessionData.Entity.Get(char)
	if not data then return end
	if not Turn.Utils.IsEntityInTurn(char) then return end
	if not Turn.Utils.IsEntityTurn(char) then return end
	
	
	local turnid = Turn.Utils.GetEntityTurnId(char)
	local targets: TypesTurn.entities = if data.temp.state == "ally"
		then Turn.Utils.GetEntitiesByState(turnid, "enemy")
		else Turn.Utils.GetEntitiesByState(turnid, "ally")
	
	local entity: TypesTurn.entityitem = targets[GetClosestEntityId(char, targets)]
	local node = Navigation.GetClosestNode(
		WorldCell.GetCellFloorFromWorkspace(data.temp.worldcell.currentCell), 
		entity.char:GetPivot().Position
	)

	Action.Execute(char, "Movimentation", "WalkTo", node.position)
end


return {
	DetectAheadForCombat = DetectAheadForCombat,
	ExecuteTurn = ExecuteTurn
}