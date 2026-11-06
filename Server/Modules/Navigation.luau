-- Serviços
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Módulos
local INFO = require(ServerScriptService.Systems.Modules.INFO).Navigation
local TypesNavigation = require(ReplicatedStorage.Types.Navigation)

local showNode = false
local nodes: { [Model]: { TypesNavigation.node } } = {}

local debugFolder = Instance.new("Folder")
debugFolder.Name = "NavigationDebug"
debugFolder.Parent = workspace

-------------------------------------------------------
-- Funções Locais
local function ShowNode(position: Vector3, id: number): ()
	local marker = Instance.new("Part")
	marker.Name = tostring(id)
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(0.25, 0.25, 0.25)
	marker.Position = position
	marker.Color = Color3.fromRGB(70, 255, 120)
	marker.Material = Enum.Material.Neon
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Parent = debugFolder
end
local function ConnectNodes(node: TypesNavigation.node, neighbor: TypesNavigation.node?): ()
	if not neighbor then return end
	table.insert(node.neighbors, neighbor)
	table.insert(neighbor.neighbors, node)
end
local function GetClosestNode(floor: Model, position: Vector3): TypesNavigation.node?
	local closestNode: TypesNavigation.node? = nil
	local closestDistance = math.huge

	for _, node in nodes[floor] or {} do
		local distance = (node.position - position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestNode = node
		end
	end

	return closestNode
end
local function GetFloorSurface(floor: Model, x: number, z: number, height: number?): (Part?, Vector3?)
	for _, part in floor:GetDescendants() do
		if not part:IsA("Part") then continue end
		if part.Shape ~= Enum.PartType.Block then continue end

		local half = part.Size / 2
		local point = part.CFrame:PointToObjectSpace(Vector3.new(x, part.Position.Y, z))
		if math.abs(point.X) > half.X or math.abs(point.Z) > half.Z then continue end

		local top = part.CFrame:PointToWorldSpace(Vector3.new(point.X, half.Y, point.Z))
		if height ~= nil and math.abs(height - top.Y) > INFO.floorHeightTolerance then continue end
		return part, top
	end

	return nil, nil
end

-------------------------------------------------------
-- Funções Módulo
local function FindPath(floor: Model, origin: Vector3, destination: Vector3): { TypesNavigation.node }?
	if not GetFloorSurface(floor, destination.X, destination.Z, destination.Y) then return end

	local startNode = GetClosestNode(floor, origin)
	local endNode = GetClosestNode(floor, destination)
	if not startNode or not endNode then return end

	local open: { TypesNavigation.node } = { startNode }
	local cameFrom: { [TypesNavigation.node]: TypesNavigation.node } = {}
	local gScore: { [TypesNavigation.node]: number } = { [startNode] = 0 }
	local fScore: { [TypesNavigation.node]: number } = { [startNode] = (startNode.position - endNode.position).Magnitude }

	-- Retira da busca o nó com menor custo estimado.
	local function GetBestNode(): TypesNavigation.node
		local bestIndex = 1

		for index = 2, #open do
			if fScore[open[index]] < fScore[open[bestIndex]] then
				bestIndex = index
			end
		end

		return table.remove(open, bestIndex)
	end

	-- Verifica se existe chão ao longo do trecho.
	local function CanWalkStraight(from: Vector3, to: Vector3): boolean
		local distance = (to - from).Magnitude
		local steps = math.max(1, math.ceil(distance / (INFO.nodeSpacing / 4)))

		for step = 0, steps do
			local point = from:Lerp(to, step / steps)

			if not GetFloorSurface(floor, point.X, point.Z, point.Y) then
				return false
			end
		end

		return true
	end

	-- Reconstrói o caminho e mantém apenas os pontos necessários.
	local function BuildPath(): { TypesNavigation.node }
		local current = endNode
		local path: { TypesNavigation.node } = { current }

		while cameFrom[current] do
			current = cameFrom[current]
			table.insert(path, current)
		end

		local waypoints: { TypesNavigation.node } = { path[#path] }
		local currentIndex = #path

		while currentIndex > 1 do
			local nextIndex = currentIndex - 1

			for candidate = 1, currentIndex - 2 do
				if CanWalkStraight(path[currentIndex].position, path[candidate].position) then
					nextIndex = candidate
					break
				end
			end

			table.insert(waypoints, path[nextIndex])
			currentIndex = nextIndex
		end

		return waypoints
	end

	local function ShowPath(path: { TypesNavigation.node }): ()
		for _, node in path do
			local marker = debugFolder:FindFirstChild(tostring(node.id))

			if marker and marker:IsA("BasePart") then
				marker.Color = Color3.fromRGB(255, 80, 80)
			end
		end
	end

	-- Busca o caminho.
	while #open > 0 do
		local current = GetBestNode()

		if current == endNode then
			local path = BuildPath()
			if ShowNode then
				ShowPath(path)
			end

			return path
		end

		for _, neighbor in current.neighbors do
			local cost = gScore[current] + (current.position - neighbor.position).Magnitude
			if cost >= (gScore[neighbor] or math.huge) then continue end

			cameFrom[neighbor] = current
			gScore[neighbor] = cost
			fScore[neighbor] = cost + (neighbor.position - endNode.position).Magnitude

			if not table.find(open, neighbor) then
				table.insert(open, neighbor)
			end
		end
	end
end

local function Setup(floor: Model): ()
	local floorNodes: { TypesNavigation.node } = {}
	nodes[floor] = floorNodes

	local spacing = INFO.nodeSpacing
	local grid: { [number]: { [number]: TypesNavigation.node } } = {}

	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	-- Calcula os limites da grade.
	for _, part in floor:GetDescendants() do
		if not part:IsA("Part") then continue end
		if part.Shape ~= Enum.PartType.Block then continue end

		local half = part.Size / 2

		for _, x in { -half.X, half.X } do
			for _, z in { -half.Z, half.Z } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(x, half.Y, z))
				minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
				minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
			end
		end
	end

	if minX == math.huge then return end

	-- Cria os nós na altura real do chão.
	local columns = math.floor((maxX - minX) / spacing + 0.5)
	local rows = math.floor((maxZ - minZ) / spacing + 0.5)

	for col = 1, columns do
		grid[col] = {}

		for row = 1, rows do
			local x = minX + (col - 0.5) * spacing
			local z = minZ + (row - 0.5) * spacing
			local part, position = GetFloorSurface(floor, x, z)

			if not part or not position then continue end

			local node: TypesNavigation.node = {
				id = #floorNodes + 1,
				position = position,
				neighbors = {},
				part = part,
			}

			grid[col][row] = node
			table.insert(floorNodes, node)

			if showNode then ShowNode(position, node.id) end
		end
	end

	-- Conecta os vizinhos na horizontal, vertical e diagonal.
	for col, column in grid do
		for row, node in column do
			ConnectNodes(node, column[row - 1])

			local previousColumn = grid[col - 1]
			local left = previousColumn and previousColumn[row]
			if not left then continue end

			ConnectNodes(node, left)

			for _, offset in { -1, 1 } do
				if column[row + offset] then
					ConnectNodes(node, previousColumn[row + offset])
				end
			end
		end
	end
end

return {
	FindPath = FindPath,
	Setup = Setup,
	GetClosestNode = GetClosestNode
}