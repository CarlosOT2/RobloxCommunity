-- Serviços
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

-- Variáveis
local Animations = ReplicatedStorage.Assets.Animation
local LocalPlayer = Players.LocalPlayer
-- Módulos
local LocalData = require(script.Parent.Parent.Modules.Data.LocalData)
local VerifyIsChar = require(ReplicatedStorage.Utils.VerifyIsChar)

--------------------------------------------------------------------------------
-- Types

type TrackObj = {
	Name: string,
	Track: AnimationTrack?
}

type CharTracks = {
	CurrentTrack: TrackObj,
	[string]: TrackObj
}

type LoadAnimItem = {
	track: AnimationTrack
}

type PreloadedItem = {
	Animation: Animation
}

type AnimData = {
	Tracks: { [string]: CharTracks? },
	Preloaded: { [string]: PreloadedItem }
}

type PlayConfig = {
	animType: string,
	char: Model,
	replayable: boolean?
}

--------------------------------------------------------------------------------
-- Variáveis do módulo

local Animation = {}

local AnimData: AnimData = {
	Tracks = {},
	Preloaded = {}
}

--------------------------------------------------------------------------------
-- Consulta

function Get()
	return AnimData
end

--------------------------------------------------------------------------------
-- Carregamento
function preload()
	local animsToPreload = {}

	for _, anim in Animations:GetChildren() do
		if anim:IsA("Animation") then
			table.insert(animsToPreload, anim)
			AnimData.Preloaded[anim.Name] = {
				Animation = anim
			}
		end
	end

	if #animsToPreload == 0 then
		warn("Animation: Nenhuma animação encontrada.")
		return
	end

	local success, err = pcall(function()
		ContentProvider:PreloadAsync(animsToPreload)
	end)

	if not success then
		warn("Animation: Erro durante PreloadAsync:", err)
	end
end

local function LoadAnim(animType: string, char: Model): LoadAnimItem?
	local Preloaded = AnimData.Preloaded[animType]
	if not Preloaded then
		warn("Animation.LoadAnim(): Animação não encontrada:", animType)
		return
	end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		warn("Animation.LoadAnim(): Animator não encontrado:", char.Name)
		return
	end

	return {
		track = animator:LoadAnimation(Preloaded.Animation)
	}
end

--------------------------------------------------------------------------------
-- Controle de tracks

local function Template(): TrackObj
	return { Name = "Template", Track = nil }
end

local function Stop(char: Model, config: { animType: string?, CurrentTrack: boolean? })
	local targetTracks = AnimData.Tracks[char.Name]
	if not targetTracks then return end

	local function stopTrack(name: string)
		local trackObj = targetTracks[name]
		if trackObj and trackObj.Track then
			trackObj.Track:Stop()
		end
		targetTracks[name] = nil
	end

	if config.CurrentTrack then
		local current = targetTracks.CurrentTrack
		if current.Track then
			current.Track:Stop()
		end

		targetTracks[current.Name] = nil
		targetTracks.CurrentTrack = Template()
	end

	if config.animType then
		stopTrack(config.animType)
	end
end

function StopAllTracks(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")

	if not animator then return end
	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop()
	end
end

--------------------------------------------------------------------------------
-- Reprodução

function Play(config: PlayConfig)
	local char = config.char
	local animType = config.animType
	
	local targetTracks = AnimData.Tracks[char.Name] or { CurrentTrack = Template() }
	local current = targetTracks.CurrentTrack
	if current.Track and animType == current.Track.Name then return end

	
	if current.Track then 
		Stop(char, { CurrentTrack = true })
	end

	local loaded = LoadAnim(animType, char)
	if not loaded then return end

	local newTrack: TrackObj = { Name = animType, Track = loaded.track }

	targetTracks.CurrentTrack = newTrack
	targetTracks[animType] = newTrack
	AnimData.Tracks[char.Name] = targetTracks

	newTrack.Track:Play()
	newTrack.Track:AdjustSpeed(1)
end

--------------------------------------------------------------------------------
-- Funções de movimento

local function onWalk(char: Model)
	Play({
		char = char,
		animType = "Walk",
		replayable = true
	})
end

local function onIdle(char: Model)
	LocalData.Get({ Type = "Clients", char = char })
	Play({
		char = char,
		animType = "Idle"
	})
end

--------------------------------------------------------------------------------

return {
	onWalk = onWalk,
	onIdle = onIdle,
	Stop = Stop,
	preload = preload
}