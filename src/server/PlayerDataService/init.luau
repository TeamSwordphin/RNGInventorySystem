--[[

	Handles loading of player's inventory saves.

	@author Phin 2024

]]

local INVENTORY_SCOPE = "Inventory_Scope_1"
local SAVE_KEY = "_Inventory_Save"
local MOCK_STORES = game:GetService("RunService"):IsStudio() --- If true, only load mock Profile stores which automatically wipes after the end of sessions.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileService = require(ReplicatedStorage.Libraries.ProfileService)
local ReplicaService = require(ReplicatedStorage.Libraries.ReplicaService)

local PlayerDataStore = ProfileService.GetProfileStore(INVENTORY_SCOPE, require(ReplicatedStorage.Modules.PlayerData))
local PlayerDataService = { _Datas = {}, _Replicas = {} }

if MOCK_STORES then
	PlayerDataStore = PlayerDataStore.Mock
end

--- Fetches the Profile of the player
-- @params player: Player -> The player to get the profile from
function PlayerDataService:GetProfile(player: Player)
	return PlayerDataService._Datas[player]
end

--- Fetches a key from a player's Profile
-- @params player: Player -> The player to get the profile from
-- @params key: string -> The key within the Profile.Data to fetch
function PlayerDataService:Get(player: Player, key: string)
	local data = PlayerDataService:GetProfile(player)

	if data then
		return data.Data[key]
	end

	return
end

--- Sets a value given a key inside a player's Profile, and additionally replicate this change to the player
-- @params key: string -> The key within the Profile.Data to set
-- @params value: any -> The value within Profile.Data[key] to set
function PlayerDataService:Set(player: Player, key: string, value: any)
	local data = PlayerDataService:GetProfile(player)

	if data then
		if typeof(data.Data[key]) == typeof(value) then
			data.Data[key] = value
			PlayerDataService._Replicas[player]:SetValue({ key }, value)
		end
	end
end

--- Initializes their save states when they first join the game, and also cleans up when they leave
function PlayerAdded(player: Player)
	local profile = PlayerDataStore:LoadProfileAsync(`{player.UserId}{SAVE_KEY}`, "ForceLoad")

	if profile then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			PlayerDataService._Replicas[player]:Destroy()
			PlayerDataService._Replicas[player] = nil
			PlayerDataService._Datas[player] = nil

			print(`{player.Name} left and their data automatically saved!`)
		end)

		if player and player:IsDescendantOf(Players) then
			PlayerDataService._Datas[player] = profile
			PlayerDataService._Replicas[player] = ReplicaService.NewReplica({
				ClassToken = ReplicaService.NewClassToken(`{player.UserId}_PlayerDataToken`),
				Data = profile.Data,
				Replication = player,
			})

			print(`{player.Name} data loaded!`)
		else
			profile:Release()
		end
	else
		if player then
			player:Kick("Your data could not be loaded. Try again later.")
		end
	end
end

function PlayerRemoving(player: Player)
	PlayerDataService._Datas[player]:Release()
end

local function Init()
	for _, player in Players:GetPlayers() do
		PlayerAdded(player)
	end

	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
end

Init()
return PlayerDataService
