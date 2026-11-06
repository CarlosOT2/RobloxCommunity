-- Serviços
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Local Player
local LocalPlayer = game.Players.LocalPlayer
-- RE
local TurnEvent = ReplicatedStorage.RE:WaitForChild("Turn")
-- Módulos
local Connectors = require(script.Parent.Parent.Modules.Utils.Connectors)
local LocalData = require(script.Parent.Parent.Modules.Data.LocalData)
local Camera = require(script.Parent.Parent.Modules.Camera)
local Expressions = require(script.Parent.Parent.Modules.PlayerFX.Expression)
local TypesTurn = require(ReplicatedStorage.Types.Turn)
local CloneCharacter = require(script.Parent.Parent.Modules.Utils.CloneCharacter)
-- Connections
local Connections: Connectors.Type = {}


-- GUI
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local HUD: ScreenGui = PlayerGui:WaitForChild("HUD"):WaitForChild("HUD") :: ScreenGui

local TurnEntities: Frame = HUD:WaitForChild("TurnEntities") :: Frame
local Entities: Folder = TurnEntities:WaitForChild("Entities") :: Folder
local TurnEntitiesItem = ReplicatedStorage.Assets.UI.GUI.Templates.Turn:WaitForChild("TurnEntitiesItem")

HUD.Enabled = true

--------------------------------------------------------------------------------------------------------------
-- Funções GUI

local function SetEntityGUI(entity: TypesTurn.entityitem)
	local GuiEntityItem = Entities:FindFirstChild(entity.char.Name)
	if not GuiEntityItem then
		GuiEntityItem = TurnEntitiesItem:Clone()
		GuiEntityItem.Name = entity.char.Name
		GuiEntityItem.Parent = Entities
	end

	-- Char
	local char = entity.char
	local ViewportFrame = GuiEntityItem:WaitForChild("ViewportFrame")

	-- Limpa chars antigos
	for _, instance in ipairs(ViewportFrame:GetDescendants()) do
		if instance:IsA("Model") then
			instance:Destroy()
		end
	end
	
	-- Clone do char
	local cloneChar = CloneCharacter(char)
	cloneChar.PrimaryPart = cloneChar:FindFirstChild("HumanoidRootPart")
	cloneChar.Parent = ViewportFrame

	-- Camera
	local camera = ViewportFrame:FindFirstChildOfClass("Camera") or Instance.new("Camera")
	camera.Parent = ViewportFrame
	ViewportFrame.CurrentCamera = camera
	
	local head = cloneChar:FindFirstChild("Head")
	camera.CFrame = CFrame.lookAt(
		head.Position + head.CFrame.LookVector * 2.5 + Vector3.new(0, 0.3, 0),
		head.Position
	)
end
local function SetEntitiesGUI(entities: TypesTurn.entities)
	for index, entity in pairs(entities) do
		SetEntityGUI(entity)

		local GuiEntityItem: Frame = Entities:FindFirstChild(entity.char.Name)
		if GuiEntityItem then
			GuiEntityItem.LayoutOrder = index
		end
	end
end

local function Setup(char)
	local TurnData = LocalData.Get({ Type = "CurrentClient" }).turn
	local CameraData = LocalData.Get({ Type = "CurrentClient" }).others.camera

	Connectors.DisconnectAll(Connections)
	Connections = {
		Event = TurnEvent.OnClientEvent:Connect(function(config: Types.turnclientconfig)
			-- Não Obrigatórios
			local Type = config.Type
			local entities = config.entities
			

			SetEntitiesGUI(entities)
			
			local currentTurnChar = entities[1].char
			if CameraData.target ~= currentTurnChar then
				Camera.SetModeTarget("above", currentTurnChar, 0.5)
			end
			
			if Type  then
				if Type == "Start" then
					TurnData.active = true
				else
					TurnData.active = false
				end
			end
		end)
	}
end

if LocalPlayer.Character then
	Setup(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char: Model)
	Setup(char)
end)