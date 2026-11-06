-- Serviços
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
-- Player
local LocalPlayer: Player = Players.LocalPlayer
-- Módulos
local Animation = require(script.Parent.Animation)
local Connectors = require(script.Parent.Parent.Modules.Utils.Connectors)

-- Connections
local Connections: Connectors.Type = {}

------------------------------------------------------------------------------------------------
-- Preload
local success, err = pcall(Animation.preload)
if not success then
	warn("LocalAnimation: Error ao executar Animation.preload():", err)
	return 
end

------------------------------------------------------------------------------------------------
-- Funções
function setupAnimation(char: Model)
	local hrp: Part = char:FindFirstChild("HumanoidRootPart") :: Part
	local hum: Humanoid = char:FindFirstChild("Humanoid") :: Humanoid
	local animate: LocalScript = char:FindFirstChild("Animate")
	
	-- Remove o script padrão de animação do roblox
	if animate then
		animate:Destroy()
	end
	-- Para Qualquer Animação Tocando
	local animator: Animator = hum:FindFirstChildOfClass("Animator") :: Animator
	for _, track in pairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end

	-- Define a animação inicial
	if hum then 
		Animation.onIdle(char)
	end
end

if LocalPlayer.Character then
	setupAnimation(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	setupAnimation(char)
end)

















