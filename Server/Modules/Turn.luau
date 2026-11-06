-- Serviços
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
-- RE
local TurnEvent = ReplicatedStorage.RE.Turn
-- Módulos
local SessionData = require(ServerScriptService.Data.SessionData)
local DefaultData = require(ServerScriptService.Data.DefaultData)

local TypesTurn = require(ReplicatedStorage.Types.Turn)
local TypesEntity = require(ReplicatedStorage.Types.EntityData)

local turns: { [string]: TypesTurn.turnitem } = {}

------------------------------------------------------------
-- Funções Utils

local function GetTurn(turnid: string): TypesTurn.turnitem
	return turns[turnid]
end
local function GetAll(): { [string]: TypesTurn.turnitem }
	return turns
end
local function GetEntityId(char: Model): string?
	for _, turn in pairs(turns) do
		for entityid, entity in pairs(turn.entities) do
			if entity.char == char then
				return entityid
			end
		end
	end

	return nil
end
local function GetEntityTurnId(char: Model): string?
	for turnid, turn in pairs(turns) do
		for _, entity in pairs(turn.entities) do
			if entity.char == char then
				return turnid
			end
		end
	end

	return nil
end
local function GetEntitiesByState(turnid: string, state: TypesEntity.states): TypesTurn.entities?
	local turn = GetTurn(turnid)
	if not turn then return end

	local entities: TypesTurn.entities = {}
	for _, entity in pairs(turn.entities) do
		local data = SessionData.Entity.Get(entity.char)
		if not data then continue end
		if data.temp.state ~= state then continue end

		entities[entity.entityid] = { entityid = entity.entityid, char = entity.char }
	end

	return entities
end

local function IsEntityInTurn(char: Model): boolean
	for _, turn in pairs(turns) do
		for _, entity in pairs(turn.entities) do
			if entity.char == char then
				return true
			end
		end
	end

	return false
end
local function IsEntityTurn(char: Model): boolean
	local turnid = GetEntityTurnId(char)
	if not turnid then return false end

	local turn = GetTurn(turnid)
	if not turn then return false end

	local current = turn.order.queue[1]
	if not current then return false end

	local entity = turn.entities[current.entityid]
	if not entity then return false end

	return entity.char == char
end

local function CanStart(entities: { Model })
	local enemyexist = false
	local allyexist = false

	for _, entity in pairs(entities) do
		local data = SessionData.Entity.Get(entity)
		if not data then continue end
		
		if data.temp.state == "ally" then
			allyexist = true
		end
		if data.temp.state == "enemy" then	
			enemyexist = true
		end
		
		if enemyexist and allyexist then return true end
	end
	
	return false
end
local function CanEnd(turnid: string)
	local turn = GetTurn(turnid)
	if not turn then return end
	
	for _, obj in pairs(turn.entities) do
		local entitydata = SessionData.Entity.Get(obj.char)
		if not entitydata then continue end 
		if entitydata.temp.state == "enemy" then return false end
	end 

	return true
end

------------------------------------------------------------
-- Funções Locais
local function FireEvent(char: Model) 
	local data = SessionData.Entity.Get(char)
	
	if not data then return end 
	if not (data.type == "player") then return end 
	
	local turnid = GetEntityTurnId(char)
	if not turnid then
		warn('Error Turn.FireEvent(), não foi encontrado o turn', char.Name)
		return
	end
	
	local turn = GetTurn(turnid)
	
	-- Monta uma lista de entidades seguindo a ordem da fila.
	local orderedEntities = {}
	for _, item in ipairs(turn.order.queue) do
		local entity = turn.entities[item.entityid]
		if not entity then continue end
		table.insert(orderedEntities, { entityid = item.entityid, char = entity.char })
	end
	

	TurnEvent:FireClient(data.references.player, { 
		Type = 'Start', 
		entities = orderedEntities
	}) 
end

------------------------------------------------------------
-- Funções

-- Entity 
function AddEntity(char: Model, turnid: string)
	local data = SessionData.Entity.Get(char)
	if not data then return end
	
	AddToEntities(char, turnid)
	AddToOrder(char)
end
function AddToEntities(char: Model, turnid: string)
	local data = SessionData.Entity.Get(char)
	if not data then return end

	-- Variáveis
	local entityid = data.entityid
	local turn = GetTurn(turnid)

	
	if not turn then
		warn('Error Turn.AddToEntity, Turn não encontrado, turnid:', turnid)
		return
	end
	if IsEntityInTurn(char) then 
		warn('Error Turn.AddToEntity, Entity já está em um turno, turnid:', turnid)
		return 
	end
	
	turn.entities[entityid] = {
		entityid = entityid,
		char = char
	}
	
	return data.entityid
end
function SetupEntities(turnid: string, entities: TypesTurn.entities)
	for _, obj in pairs(entities) do
		local entitydata = SessionData.Entity.Get(obj.char)
		if not entitydata then continue end 
		
		AddToEntities(obj.char, turnid)
	end
end

-- Order
function SetupOrder(turnid: string)
	local turn = GetTurn(turnid)
	if not turn then
		warn('Error Turn.SetupOrder, Turn não encontrado, turnid:', turnid)
		return
	end

	for _, obj in pairs(turn.entities) do
		AddToOrder(obj.char)
	end
	
	-- Sorteia uma prioridade fixa para desempatar iniciativas iguais.
	local randomPriority = {}
	for _, item in ipairs(turn.order.queue) do
		randomPriority[item] = math.random()
	end

	table.sort(turn.order.queue, function(a, b)
		-- Em caso de empate, quem recebeu a maior prioridade vem primeiro.
		if a.initiative == b.initiative then
			return randomPriority[a] > randomPriority[b]
		end

		-- Fora dos empates, a maior iniciativa vem primeiro.
		return a.initiative > b.initiative
	end)

end
function AddToOrder(char: Model)
	local data = SessionData.Entity.Get(char)
	if not data then return end 
	
	local turnid = GetEntityTurnId(char)
	if not turnid then
		warn('Error Turn.AddToOrder, Turn não encontrado, turnid:', turnid)
		return
	end
	
	local turn = GetTurn(turnid)
	local entityid = GetEntityId(char)
	local item = {
		entityid = entityid,
		initiative = data.stats.initiative
	}
	
	table.insert(turn.order.queue, item)
end

function Next(turnid: string)
	local turn = GetTurn(turnid)
	
	if not turn then
		warn('Error Turn.Next, Turn não encontrado, turnid:', turnid)
		return
	end
	
	local queue = turn.order.queue
	if #queue <= 1 then return end

	local first = table.remove(queue, 1)
	table.insert(queue, first)
end

-- State
function GetState(turnid: string): TypesTurn.turnstates?
	local turn = GetTurn(turnid)
	if not turn then return end

	return turn.state
end
function SetState(turnid: string, newState: TypesTurn.turnstates): boolean
	local turn = GetTurn(turnid)
	if not turn then return false end
	
	turn.state = newState
	return true
end

-- Turn
function Start(entities: TypesTurn.entities)
	-- Filtra e valida as entidades.
	local filteredEntities = {}
	for _, obj in pairs(entities) do
		local data = SessionData.Entity.Get(obj.char)
		if not data then return end
		
		if IsEntityInTurn(obj.char) then return end

		table.insert(filteredEntities, obj)
	end

	-- Setando
	local turnid = HttpService:GenerateGUID(false)
	turns[turnid] = {
		turnid = turnid,
		state = "awaitinginput",
		order = { queue = {} },
		entities = {},
		started = os.clock()
	}
	
	SetupEntities(turnid, filteredEntities)
	SetupOrder(turnid)
	
	for _, obj in pairs(turns[turnid].entities) do
		FireEvent(obj.char)
	end
	
	return turnid
end
function End(turnid: string)
	local turn = GetTurn(turnid)
	if not turn then return end
	
	--[[
	for _, obj in pairs(turn.entities) do
		local entitydata = SessionData.Entity.Get(obj.char)
		if not entitydata then continue end
		
		if entitydata.type == "player" then
			TurnEvent:FireClient(obj.char, { Type = 'End' })
		end

		RemoveEntity(obj.char)
	end

	-- Remove Turno
	turns[turnid] = nil
	]]--
	-- Remove Entidades
end

return {
	Start = Start,
	End = End,

	State = {
		Get = GetState,
		Set = SetState,
	},
	
	Order = {
		Next = Next
	},
	Entity = {
		Add = AddEntity
	},
	Event = {
		Fire = FireEvent
	},
	
	Utils = {
		IsEntityInTurn = IsEntityInTurn,
		GetEntityTurnId = GetEntityTurnId,
		GetEntitiesByState = GetEntitiesByState,
		GetTurn = GetTurn,
		GetAll = GetAll,
		CanEnd = CanEnd,
		CanStart = CanStart,
		IsEntityTurn = IsEntityTurn
	}
}