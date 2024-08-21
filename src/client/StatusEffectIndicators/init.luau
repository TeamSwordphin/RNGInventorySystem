--[[

	Handles the creation and management of the status effect indicators on the client.

	@author Phin 2024

]]

export type StatusEffect = {
	Id: number,
	Image: string?,
	Duration: number?,
	Rolls: number?,
}

export type StatusEffectBinder = {
	_janitor: any,
	_frame: Frame,
	_tween: Tween?,
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cooldowns = require(ReplicatedStorage.Modules.Cooldowns)
local Janitor = require(ReplicatedStorage.Libraries.Janitor)

local StatusUI

local StatusEffect = {}
local _Statuses: { StatusEffectBinder } = {}

local function CreateBinder(image: string): StatusEffectBinder
	local janitor = Janitor.new()
	local element = janitor:Add(StatusUI.Elements.StatusFrame:Clone(), "Destroy")
	element.Icon.Image = image
	element.Visible = true
	element:AddTag("_UIStatusEffect")
	element.Parent = StatusUI.StatusEffects.Placement

	return {
		_janitor = janitor,
		_frame = element,
	}
end

function StatusEffect:Add(data: StatusEffect)
	local get: StatusEffectBinder? = StatusEffect:Get(data.Id)

	if not get then
		get = CreateBinder(data.Image or "")
	end

	local element = get

	-- Check if there is an existing duration
	if element._tween then
		element._tween:Cancel()
	end

	element._frame.Bar.Size = UDim2.fromScale(1, 0)
	element._janitor:Remove("CurrentTween")
	element._janitor:Remove("CurrentCancellation")
	element._janitor:Remove("CurrentRunService")

	if data.Duration then
		local currentCooldown: number = Cooldowns:get(element)
		local newDuration: number = currentCooldown + data.Duration
		Cooldowns:set(element, newDuration)

		local tween: Tween = element._janitor:Add(
			TweenService:Create(
				element._frame.Bar,
				TweenInfo.new(newDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.fromScale(1, 1) }
			),
			"Cancel",
			"CurrentTween"
		)
		tween:Play()

		element._janitor:Add(
			tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
				if playbackState == Enum.PlaybackState.Completed then
					StatusEffect:Remove(data.Id)
				end
			end),
			"Disconnect",
			"CurrentCancellation"
		)

		element._janitor:Add(
			RunService.PostSimulation:Connect(function()
				element._frame.Timer.Text = (string.format("%.1f", Cooldowns:get(element)))
			end),
			"Disconnect",
			"CurrentRunService"
		)

		element._tween = tween
	elseif data.Rolls then
		element._janitor:Add(
			RunService.PostSimulation:Connect(function()
				local currentRolls = Players.LocalPlayer:GetAttribute(`Potion{data.Id}Rolls`) or 0
				local maxRolls = Players.LocalPlayer:GetAttribute(`Potion{data.Id}RollsMax`) or 0

				element._frame.Bar.Size = UDim2.fromScale(1, (maxRolls - currentRolls) / maxRolls)
				element._frame.Timer.Text = `x{currentRolls}`

				if currentRolls <= 0 then
					StatusEffect:Remove(data.Id)
				end
			end),
			"Disconnect",
			"CurrentRunService"
		)
	end

	_Statuses[data.Id] = element
end

function StatusEffect:Get(id: number): StatusEffectBinder?
	return _Statuses[id]
end

function StatusEffect:Remove(id: number)
	local get: StatusEffectBinder? = StatusEffect:Get(id)

	if get then
		get._janitor:Destroy()
		Cooldowns:destroy(get)
		_Statuses[id] = nil
	end
end

local function Init()
	StatusUI = Players.LocalPlayer.PlayerGui:WaitForChild("StatusEffects")
end

Init()
return StatusEffect
