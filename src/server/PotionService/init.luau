--[[

	Manages spawning of potions

	@author Phin 2024

]]

local DEFAULT_SPAWN_INTERVAL = 1 --- How long does a potion spawn inside a region
local DEFAULT_REMOVAL_INTERVAL = 20 --- How long the potion gets removed if not collected for a time

local REGION_TAG = "PotionSpawnRegion" --- The tag to use for detecting regions
local POTION_PARENT_FOLDER_NAME = "PotionEntityFolder"

local DEFAULT_POTION_SERVER_HITBOX_SIZE = Vector3.new(1.8, 1.8, 1.8)
local MAXIMUM_ALLOWABLE_GRAB_DISTANCE = 6

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(script.Parent.PlayerDataService)
local Janitor = require(ReplicatedStorage.Libraries.Janitor)
local Zap = require(ServerScriptService.Network.Zap)

local Cooldowns = require(ReplicatedStorage.Modules.Cooldowns)
local PotionData = require(ReplicatedStorage.Modules.PotionData)
local PotionList = PotionData:GetPotionList()

export type Zone = {
	_janitor: any,
	_zone: BasePart,
	_tick: number,
	Destroy: (self: Zone) -> (),
}

local _Seed: Random = Random.new()
local _Parent: Folder
local _Zones: { [BasePart]: Zone } = {}

local PotionSpawnerRegion = {}

local function GetRandomPoint(zone: BasePart): Vector3
	return (zone.CFrame * CFrame.new(
		(_Seed:NextNumber() - 0.5) * zone.Size.X,
		(_Seed:NextNumber() - 0.5) * zone.Size.Y,
		(_Seed:NextNumber() - 0.5) * zone.Size.Z
	)).Position
end

local function GenerateRegion(zone: BasePart)
	assert(zone, "Zone must be a valid BasePart!")

	PotionSpawnerRegion:RemoveRegion(zone)

	local _zoneJanitor = Janitor.new()
	local _tick = DEFAULT_SPAWN_INTERVAL

	_zoneJanitor:Add(RunService.PostSimulation:Connect(function(delta: number)
		_tick += delta

		if _tick >= DEFAULT_SPAWN_INTERVAL then
			_tick = 0

			-- Choose a random potion to spawn
			local id = _Seed:NextInteger(1, #PotionList)
			local choice = PotionList[id]

			-- Create a dummy part that clients can hook onto
			local potion = _zoneJanitor:Add(Instance.new("Part"), "Destroy")
			potion.Transparency = 1
			potion.Size = DEFAULT_POTION_SERVER_HITBOX_SIZE
			potion.Position = GetRandomPoint(zone)
			potion:AddTag("_Potion")
			potion:SetAttribute("Type", choice.Name)
			potion.Parent = _Parent
			potion:SetNetworkOwner(nil)

			local debounce: boolean = false
			potion.Touched:Connect(function(part: BasePart)
				if debounce then
					return
				end

				local player: Player? = Players:GetPlayerFromCharacter(part.Parent)

				if player then
					-- Sanity check to ensure they are close enough to grab this potion
					local character: Model? = player.Character

					if not character then
						return
					end

					local rootPart: BasePart? = character.PrimaryPart

					if rootPart then
						local distance: number = (potion.Position - rootPart.Position).Magnitude

						if distance <= MAXIMUM_ALLOWABLE_GRAB_DISTANCE then
							debounce = true
							potion:Destroy()

							-- Make sure the category exists in the inventory. This separates the inventory limit per category
							local inventory = PlayerData:Get(player, "PotionInventory")
							id = tostring(id)

							if not inventory[id] then
								inventory[id] = 1
							else
								inventory[id] += 1
							end

							PlayerData:Set(player, "PotionInventory", inventory)
						end
					end
				end
			end)

			_zoneJanitor:Add(task.delay(DEFAULT_REMOVAL_INTERVAL, potion.Destroy, potion))
		end
	end))

	local newZone: Zone = {
		_janitor = _zoneJanitor,
		_tick = _tick,
		_zone = zone,
		Destroy = function()
			PotionSpawnerRegion:RemoveRegion(zone)
		end,
	}

	_Zones[zone] = newZone
end

function PotionSpawnerRegion:GetRegion(zone: BasePart): Zone?
	assert(zone, "Zone must be a valid BasePart!")
	return _Zones[zone]
end

function PotionSpawnerRegion:RemoveRegion(zone: BasePart)
	local zoneData: Zone? = PotionSpawnerRegion:GetRegion(zone)

	if zoneData then
		zoneData._janitor:Destroy()
		_Zones[zone] = nil
	end
end

-- Listen for player input
Zap.ClientRequestPotionActivate.SetCallback(function(player: Player, id: number): { success: boolean }
	local inventory = PlayerData:Get(player, "PotionInventory")
	local potion = PotionList[id]

	if not inventory or not potion then
		return { success = false }
	end

	local idStringed: string = tostring(id)

	if (inventory[idStringed] or 0) > 0 then
		inventory[idStringed] -= 1

		if inventory[idStringed] < 1 then
			inventory[idStringed] = nil
		end

		PlayerData:Set(player, "PotionInventory", inventory)

		-- Activate status effect
		local duration: number = potion.Duration
		local now: number = os.clock()
		local potionKey: string = `{id}PotionLastUse`
		local cooldownKey = `{player.UserId}{potionKey}`

		player:AddTag(`Potion_{id}`)

		if duration then
			player:SetAttribute(potionKey, now)

			local currentCooldown: number = Cooldowns:get(cooldownKey)
			local newDuration: number = currentCooldown + duration
			Cooldowns:set(cooldownKey, newDuration)

			task.delay(Cooldowns:get(cooldownKey), function()
				if player:GetAttribute(potionKey) == now then
					player:RemoveTag(`Potion_{id}`)
				end
			end)
		elseif potion.Rolls then
			local rollKey = `Potion{id}Rolls`
			local maxKey = `Potion{id}RollsMax`

			player:SetAttribute(rollKey, (player:GetAttribute(rollKey) or 0) + potion.Rolls)
			player:SetAttribute(maxKey, (player:GetAttribute(maxKey) or 0) + potion.Rolls)
		end

		return { success = true }
	end

	return { success = false }
end)

local function Init()
	local folder: Folder = workspace:FindFirstChild(POTION_PARENT_FOLDER_NAME) or Instance.new("Folder")
	folder.Name = POTION_PARENT_FOLDER_NAME
	folder.Parent = workspace
	_Parent = folder

	for _, region: BasePart in CollectionService:GetTagged(REGION_TAG) do
		GenerateRegion(region)
	end

	CollectionService:GetInstanceAddedSignal(REGION_TAG):Connect(GenerateRegion)
end

Init()
return PotionSpawnerRegion
