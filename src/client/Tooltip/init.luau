local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zap = require(ReplicatedStorage.Network.Zap)
local ItemData = require(ReplicatedStorage.Modules.ItemData)
local RandomSelection = require(ReplicatedStorage.Libraries.RandomSelection)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local Dictionary = Freeze.Dictionary

local ToolUI
local Tooltip = { _Cached = {} }

function Tooltip:DecimalNumbers(num, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

function Tooltip:Enable(data)
	local main = ToolUI.Main

	main.Position = data.Position
	main.Title.Text = data.Name or ""
	main.Title.TextColor3 = data.Rarity.Color
	main.Rarity.Text = data.Rarity.Name
	main.Rarity.TextColor3 = data.Rarity.Color
	main.Description.Text = data.Description or ""

	if data.Category then
		--- Calculate drop chance
		local items = ItemData:GetCategory(data.Category):GetItems()
		local totalWeight = RandomSelection:_getTotalWeight(Dictionary.map(items, function(data, id)
			return data.DropChance or 100, id
		end))

		main.DropChance.Count.Text = `{Tooltip:DecimalNumbers((data.DropChance / totalWeight) * 100, 2)}%`

		if not Tooltip._Cached[data.Category] then
			Tooltip._Cached[data.Category] = {}
		end

		--- Request to the server the count for this item
		if not Tooltip._Cached[data.Category][data.Id] then
			local results = Zap.RequestItemCount.Call({ category = data.Category, id = data.Id })
			Tooltip._Cached[data.Category][data.Id] = results.success and results.count or 0
		end

		main.FoundFrame.Count.Text = Tooltip._Cached[data.Category][data.Id]
		main.FoundFrame.Visible = true
		main.DropChance.Visible = true
	else
		main.FoundFrame.Visible = false
		main.DropChance.Visible = false
	end

	ToolUI.Enabled = true
end

function Tooltip:Disable()
	ToolUI.Enabled = false
end

function Tooltip:Cleanup()
	Tooltip:Disable()
	table.clear(Tooltip._Cached)
end

local function Init()
	ToolUI = Players.LocalPlayer.PlayerGui:WaitForChild("Tooltip")
	Tooltip:Disable()
end

Init()
return Tooltip
