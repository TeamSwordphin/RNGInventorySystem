--[[

	Example code to increase maximum inventory space. There is no sanity check to prevent exploiters so please incorporate them
	in according to your game's needs.

	@author Phin 2024

]]

local INVENTORY_SPACE_INCREASE_PER_UPGRADE = 5

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerData = require(ServerScriptService.ServerSystems.PlayerDataService)
local Zap = require(ServerScriptService.Network.Zap)

local UpgradeService = {}

--- Upgrade inventory space example
function UpgradeService:UpgradeInventory(player: Player, amount: number?)
	local profile = PlayerData:GetProfile(player)

	if not profile then
		error(`No profile found for player {player.Name}!`)
	end

	amount = amount or INVENTORY_SPACE_INCREASE_PER_UPGRADE

	--- Sets the new inventory value
	PlayerData:Set(player, "MaximumInventorySpace", PlayerData:Get(player, "MaximumInventorySpace") + amount)
end

--- Setups a Zap Function to listen to funct calls from clients for upgrading the inventory
Zap.RequestUpgradeInventorySpace.SetCallback(function(player: Player)
	UpgradeService:UpgradeInventory(player)
	return { success = true, inventory = PlayerData:Get(player, "MaximumInventorySpace") }
end)

return UpgradeService
