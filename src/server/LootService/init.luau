--[[

	Handles the random loot dropping. This is pretty basic and just showcases how it could be done. You should edit to match
	your game's needs.

	@author Phin 2024

]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ItemData = require(ReplicatedStorage.Modules.ItemData)
local DropData = require(ReplicatedStorage.Modules.DropData)
local GetTotalItemCount = require(ReplicatedStorage.Modules.GetTotalItemCount)

local RandomSelection = require(ReplicatedStorage.Libraries.RandomSelection)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local Dictionary = Freeze.Dictionary

local ItemCountTracker = require(script.Parent.ItemCountTracker)
local PlayerData = require(script.Parent.PlayerDataService)
local CraftService = require(script.Parent.CraftService)

local Zap = require(ServerScriptService.Network.Zap)

local LootService = {}

--- Returns a random category
function LootService:GetRandomCategory()
	local categories = Dictionary.keys(ItemData:GetCategories())
	return categories[Random.new():NextInteger(1, #categories)]
end

--- Returns a random item from a chosen category
-- @params category: string -> the name of the category
function LootService:DropRandomItem(category: string): number
	--- Convert the items to a weighted dictionary using Freeze's map function
	local items = ItemData:GetCategory(category):GetItems()
	local selectedItem = RandomSelection:getFromWeightedDictionary(Dictionary.map(items, function(data, id)
		return data.DropChance or 100, id
	end))

	return selectedItem
end

--- Setups a Zap Function to listen to funct calls from clients. Add this item to their inventory
Zap.RequestRandomLootDrop.SetCallback(function(player: Player)
	local profile = PlayerData:GetProfile(player)

	if not profile then
		error(`No profile found for player {player.Name}!`)
	end

	local category = LootService:GetRandomCategory()
	local inventory = PlayerData:Get(player, "Inventory")

	--- Make sure the category exists in the inventory. This separates the inventory limit per category
	if inventory[category] == nil then
		inventory[category] = {}
	end

	--- Check if the total count is lower than the maximum inventory size
	if GetTotalItemCount(inventory[category]) >= PlayerData:Get(player, "MaximumInventorySpace") then
		return { success = false, category = category, id = 0 }
	end

	--- Level of the item dropped
	local droppedLevel = Random.new():NextInteger(1, 5)
	local level = tostring(droppedLevel)

	local id = LootService:DropRandomItem(category)
	id = tostring(id)

	--- Find existing item in the player's inventory. If it exists, stack it! Else create a new item data in their inventory.
	if inventory[category][id] then
		if not inventory[category][id][level] then
			inventory[category][id][level] = { Count = 0 }
		end

		inventory[category][id][level].Count += 1
	else
		inventory[category][id] = { [level] = table.clone(DropData) }
	end

	--- Check auto roll settings and add it automatically
	local autoRollId = PlayerData:Get(player, "AutoRollCraftIndex")

	if autoRollId ~= 0 then
		CraftService:AddItem(player, autoRollId, category, id, droppedLevel, 1)
	end

	--- Set the data and replicate these changes to the client
	PlayerData:Set(player, "Inventory", inventory)

	--- Record these changes to a global counter
	ItemCountTracker:AddCount(category, id)

	return { success = true, category = category, id = id }
end)

return LootService
