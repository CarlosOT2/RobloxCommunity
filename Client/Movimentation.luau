-- Serviços
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
-- Local Player
local LocalPlayer = game.Players.LocalPlayer
-- RE 
local ActionEvent = ReplicatedStorage.RE:WaitForChild("Action")
local MovimentationEvent = ReplicatedStorage.RE:WaitForChild("Movimentation")
-- Módulos
local Connectors = require(script.Parent.Parent.Modules.Utils.Connectors)
local LocalData = require(script.Parent.Parent.Modules.Data.LocalData)
local Animation = require(script.Parent.Parent.Animation.Animation)
-- Connections
local Connections: Connectors.Type = {}

-- GUI
local PlayerGUI = LocalPlayer:WaitForChild("PlayerGui")
-- Decal
local Circle = ReplicatedStorage.Assets.UI:WaitForChild("MovimentationCircle")
local Arrow = ReplicatedStorage.Assets.UI:WaitForChild("MovimentationArrow")

local mouse = LocalPlayer:GetMouse()

-- Desativa o controle padrão do roblox (pulo, wasd, etc...)
local Controller = require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
Controller:Disable() 

local function DeleteIndicator(tween: boolean)
	local indicator = workspace:FindFirstChild("IndicatorUI")
	if not indicator then return end
	
	if tween then
		local billboardgui = indicator:FindFirstChildOfClass("BillboardGui")
	 
		TweenService:Create(indicator, TweenInfo.new(0.3), { Size = Vector3.new(0, 0.05, 0), Transparency = 1 }):Play()
		TweenService:Create(billboardgui, TweenInfo.new(0.3), { Size = UDim2.fromOffset(0, 0) }):Play()

		task.delay(0.3, function()
			indicator:Destroy()
		end)
	else
		indicator:Destroy()
	end
end

local function CreateIndicator(char: Model, position: Vector3)
	DeleteIndicator()
	
	-- Variáveis
	local hrp: Part = char:FindFirstChild("HumanoidRootPart") :: Part
	local DialogueData = LocalData.Get({ Type = "CurrentClient" }).dialogue
	
	-- Parte Pai
	local part = Instance.new("Part")
	part.Position = position
	part.Size = Vector3.new(0.5, 0.05, 0.5)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Name = "IndicatorUI"
	part.Parent = workspace
	
	-- BillboardGui (Seta)
	local billboardgui = Instance.new("BillboardGui")
	billboardgui.Name = "MovimentationArrow"
	billboardgui.Adornee = part
	billboardgui.AlwaysOnTop = true
	billboardgui.Size = UDim2.fromScale(9, 7)
	billboardgui.StudsOffset = Vector3.new(0, 0.75, 0)
	billboardgui.Parent = part

	-- Imagem da seta
	local image = Instance.new("ImageLabel")
	image.Name = "Arrow"
	image.Size = UDim2.fromScale(0.5, 0.6)
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.Position = UDim2.fromScale(0.5, 0)
	image.BackgroundTransparency = 1
	image.Image = Arrow.Texture
	image.ImageColor3 = Arrow.Color3
	image.Parent = billboardgui

    -- Decal (Circulo)
	local decal = Circle:Clone()
	decal.Face = Enum.NormalId.Top
	decal.Parent = part

    -- Animação de aparecimento
	TweenService:Create(part, TweenInfo.new(0.25), { Size = Vector3.new(4, 0.05, 4) }):Play()
	TweenService:Create(billboardgui, TweenInfo.new(0.25), { Size = UDim2.fromScale(4.5, 3.5) }):Play()

	-- Remove o indicador
	task.spawn(function()
		while part.Parent do
			local distance = (hrp.Position - position).Magnitude

			if distance <= 4 or DialogueData.active then
				DeleteIndicator(true)
				break
			end
			
			task.wait(0.05)
		end
	end)
end

local function Setup(char)
	-- Variáveis
	local hrp: Part = char:FindFirstChild("HumanoidRootPart") :: Part
	
	Connectors.DisconnectAll(Connections)
	Connections = {
		InputBegan = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				ActionEvent:FireServer("Movimentation", "WalkTo", mouse.Hit.Position)
			end
		end),
		
		Event = MovimentationEvent.OnClientEvent:Connect(function(char: Model, type: "Start" | "Stop" | "Indicator", position: Vector3)
			if type == "Start" then
				Animation.onWalk(char)
			elseif type == "Stop" then
				Animation.onIdle(char)
			elseif type == "Indicator" then
				CreateIndicator(char, position)
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