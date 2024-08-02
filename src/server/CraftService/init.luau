local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local List = Freeze.List

local CraftData = require(ReplicatedStorage.Modules.CraftData)
local PlayerData = require(ServerScriptService.ServerSystems.PlayerDataService)

local Zap = require(ServerScriptService.Network.Zap)

local CraftService = {}

function CraftService:AddItem(
	player: Player,
	craftIndex: number,
	category: string,
	id: any,
	level: number,
	amount: number
): boolean
	local profile = PlayerData:GetProfile(player)

	if not profile then
		error(`No profile found for player {player.Name}!`)
	end

	--- Make sure the item exists first for sanity check!
	local craftList = CraftData:GetCraftingList()
	local recipe = craftList[craftIndex]

	if not recipe then
		error(`No recipe found at index {craftIndex}!`)
	end

	id = tonumber(id)

	local requiredIngredient = List.find(recipe.Recipe, function(value)
		if value.Category == category and value.Id == id and value.Level == level then
			return true
		end

		return
	end)

	local progress = PlayerData:Get(player, "CraftProgress")

	--- Create a new progress tracker if they have never had this recipe before
	if not progress[tostring(craftIndex)] then
		progress[tostring(craftIndex)] = {}
	end

	--- Create a new ingredient tracker if they have never added this item before to this recipe
	local savedRecipe = progress[tostring(craftIndex)]
	local element = List.find(savedRecipe, function(value)
		if value.Category == category and value.Id == id and value.Level == level then
			return true
		end

		return
	end)

	if not requiredIngredient then
		--- Ingredient doesn't exist!
		return false, element and element.Count or 0
	end

	if not element then
		table.insert(savedRecipe, { Category = category, Id = id, Count = 0, Level = level or 1 })
		element = savedRecipe[#savedRecipe]
	end

	--- Make sure we aren't over-adding to this ingredient requirements
	amount = math.min(requiredIngredient.Count, amount or 1)
	amount = math.min(math.max(0, requiredIngredient.Count - element.Count), amount)

	if amount >= 1 then
		--- Check if the user has enough of this item
		local inventory = PlayerData:Get(player, "Inventory")

		--- Make sure the category exists in the inventory. This separates the inventory limit per category
		if inventory[category] == nil then
			inventory[category] = {}
		end

		local item = inventory[category][tostring(id)]

		if item then
			local stringedLevel = tostring(level)

			if item[stringedLevel] then
				if item[stringedLevel].Count >= amount then
					item[stringedLevel].Count -= amount
					element.Count += amount

					--- Remove the item from the player's save if its no more!
					if item[stringedLevel].Count <= 0 then
						item[stringedLevel] = nil
					end

					--- Set the data and replicate these changes to the client
					PlayerData:Set(player, "CraftProgress", progress)
					PlayerData:Set(player, "Inventory", inventory)

					print("Added item to craft!")

					return true, element.Count
				end
			end
		end
	end

	return false, element.Count
end

--- Zap funct request that listens to players requesting an add to a specific ingredient
Zap.AddItemToCraftIngredient.SetCallback(function(player: Player, data)
	local craftIndex = data.craftIndex
	local category = data.category
	local id = data.id
	local level = data.level
	local amount = data.amount
	local success, count = CraftService:AddItem(player, craftIndex, category, id, level, amount)

	return { success = success, count = count }
end)

--- Zap funct request that listens to players requesting to craft an item
Zap.CraftItem.SetCallback(function(player: Player, craftIndex: number)
	local craftList = CraftData:GetCraftingList()
	local recipe = craftList[craftIndex]

	if not recipe then
		error(`No recipe found at index {craftIndex}!`)
	end

	local profile = PlayerData:GetProfile(player)

	if not profile then
		error(`No profile found for player {player.Name}!`)
	end

	--- If they never put an item in, don't continue the craft!
	local progress = PlayerData:Get(player, "CraftProgress")
	local savedRecipe = progress[tostring(craftIndex)]

	if not savedRecipe or savedRecipe.Completed then
		return { success = false }
	end

	--- Sanity check to make sure they have all the necessary ingredients already put in
	for i, ingredient in recipe.Recipe do
		local element = List.find(savedRecipe, function(value)
			if
				value.Category == ingredient.Category
				and value.Id == ingredient.Id
				and value.Level == ingredient.Level
			then
				return true
			end

			return
		end)

		if not element or element.Count < ingredient.Count then
			return { success = false }
		end
	end

	--- Reward the player!
	progress[tostring(craftIndex)] = { Completed = true }

	for key, value in recipe.Rewards do
		PlayerData:Set(player, key, value)
	end

	PlayerData:Set(player, "CraftProgress", progress)

	--- Reset AutoRoll settings
	if PlayerData:Get(player, "AutoRollCraftIndex") == craftIndex then
		PlayerData:Set(player, "AutoRollCraftIndex", 0)
	end

	return { success = true }
end)

Zap.SendAutoRollIndex.On(function(player: Player, craftIndex: number)
	PlayerData:Set(player, "AutoRollCraftIndex", craftIndex)
end)

return CraftService
