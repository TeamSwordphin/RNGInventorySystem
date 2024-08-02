--[[

	Manages the global item counter.

	@author Phin 2024

]]

local UPDATE_TIME = 20 --- Updates the item count every 20 seconds by default. Don't recommend lowering this.
local SCOPE = "Test_Global_Count"
local KEY = "Test_Global_Key"

local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Zap = require(ServerScriptService.Network.Zap)

local ItemCountTracker = { _CountCache = {}, _CurrentCounterData = nil }

--- Add a count to a specific item. It will take a bit before it updates to other servers.
-- @params category: string -> the category of the item that it belongs to
-- @params id: number -> the id of the actual item
-- @params amount: number? -> Optional: adds a specific amount of this item to the counter
function ItemCountTracker:AddCount(category: string, id: string, amount: number?)
	assert(typeof(category) == "string", "Category must be a string!")
	assert(typeof(id) == "string", "Id should be a string that corrosponds to the item!")
	amount = amount or 1

	if not ItemCountTracker._CountCache[category] then
		ItemCountTracker._CountCache[category] = {}
	end

	if not ItemCountTracker._CountCache[category][id] then
		ItemCountTracker._CountCache[category][id] = 0
	end

	ItemCountTracker._CountCache[category][id] += amount
end

--- Requests the count for a specific item. May not be entirely up to date (depends on the update rate of the server)
-- @params category: string -> the category of the item that it belongs to
-- @params id: number -> the id of the actual item
function ItemCountTracker:RequestCount(data)
	local category = data.category
	local id = data.id

	if ItemCountTracker._CurrentCounterData then
		if ItemCountTracker._CurrentCounterData[category] then
			if ItemCountTracker._CurrentCounterData[category][id] then
				return ItemCountTracker._CurrentCounterData[category][id]
			end
		end
	end

	return 0
end

--- Zap funct request that listens to players requesting the count
Zap.RequestItemCount.SetCallback(function(player: Player, data)
	return { success = true, count = ItemCountTracker:RequestCount(data) }
end)

--- Run a loop that periodically updates the global counters for all items
local function Init()
	local cooldown = UPDATE_TIME
	local store = DataStoreService:GetDataStore(SCOPE)
	local studio = RunService:IsStudio()

	RunService.PostSimulation:Connect(function(dt: number)
		cooldown += dt

		if cooldown < UPDATE_TIME then
			return
		end

		cooldown = 0

		--- Merge _CountCache into this global data counter
		local success, data = pcall(function()
			return store:UpdateAsync(KEY, function(oldData, keyInfo)
				local newData = oldData or {}
				local userIds = keyInfo and keyInfo:GetUserIds()
				local metadata = keyInfo and keyInfo:GetMetadata()

				for categoryName, categoryData in ItemCountTracker._CountCache do
					if not newData[categoryName] then
						newData[categoryName] = {}
					end

					for id, count in categoryData do
						if not newData[categoryName][id] then
							newData[categoryName][id] = 0
						end

						newData[categoryName][id] += count
					end
				end

				return newData, userIds, metadata
			end)
		end)

		if success then
			table.clear(ItemCountTracker._CountCache)
			ItemCountTracker._CurrentCounterData = data
		else
			error(data)
		end

		if studio then
			print("Updated item tracker!")
		end
	end)
end

Init()
return ItemCountTracker
