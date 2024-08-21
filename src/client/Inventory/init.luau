--[[

	Handles the creation and management of the inventory system.

	@author Phin 2024

]]

local DEFAULT_CATEGORY_NAME = "All" --- Default category to open when inventory is visible

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DynamicDepth = require(ReplicatedStorage.Libraries.DynamicDepth)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local Dictionary = Freeze.Dictionary

local GetTotalItemCount = require(ReplicatedStorage.Modules.GetTotalItemCount)
local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local ItemData = require(ReplicatedStorage.Modules.ItemData)
local Zap = require(ReplicatedStorage.Network.Zap)

local Tooltip = require(script.Parent.Tooltip)

local InventoryUI

local InventorySystem = { _Inventory = nil, _CurrentCategory = nil, _MaximumInventory = 0, _Filters = {} }

--- Requests a loot drop from the server. This is connected to a button to the UI.
local function RequestLootDrop()
	local results = Zap.RequestRandomLootDrop.Call()
	local success: boolean = results.success
	local category: string = results.category

	local notifier = InventoryUI.Elements.RewardNotifier:Clone()
	notifier.Position = UDim2.fromScale(0.5, 1)
	notifier.TextTransparency = 1
	notifier.UIStroke.Transparency = 1
	notifier.Visible = true
	notifier.Parent = InventoryUI
	task.delay(4, notifier.Destroy, notifier)

	if success then
		local id: number = results.id
		local reference = ItemData:GetCategory(category)
		local item = reference:GetItem(id)
		local rarity = RarityReference[item.Rarity]

		notifier.TextColor3 = rarity.Color
		notifier.Text = `+1 {rarity.Name} Item: {item.Name}`
	else
		notifier.Text = `{category} is on cooldown!`
	end

	--- Make the notifier have some visual flair.
	local tweenInfo = TweenInfo.new(0.5)
	local goalPosition = UDim2.fromScale(0.5, 0.85)

	local tween = TweenService:Create(notifier, tweenInfo, { TextTransparency = 0, Position = goalPosition })
	TweenService:Create(notifier.UIStroke, tweenInfo, { Transparency = 0 }):Play()
	tween:Play()
	tween.Completed:Wait()

	task.wait(0.2)

	tween = TweenService:Create(notifier, tweenInfo, { TextTransparency = 1 })
	TweenService:Create(notifier.UIStroke, tweenInfo, { Transparency = 1 }):Play()
	tween:Play()
	tween.Completed:Wait()

	notifier:Destroy()
end

--- Opens the category and updates the UI within.
-- @param category: string -> the category name to open
function InventorySystem:OpenCategory(category: string)
	local inventory = InventorySystem._Inventory[category] or {}
	local maxInventory = InventorySystem._MaximumInventory
	local reference = ItemData:GetCategory(category)
	local count = GetTotalItemCount(inventory)

	InventorySystem._CurrentCategory = category
	InventoryUI.Main.Header.Inventory.Text = `Inventory: {count} / {maxInventory}`
	InventoryUI.Main.Header.Filters.Filter.DropDown.Visible = false

	--- Clear out older item frames
	for _, frame in CollectionService:GetTagged("_UIItemFrame") do
		frame:Destroy()
	end

	--- Create the new ui frames
	if count > 0 then
		for id, data in inventory do
			local item = reference:GetItem(id)

			if not item then
				continue
			end

			for level, value in data do
				local name = item.Name
				local icon = item.Icon
				local rarity = RarityReference[item.Rarity]

				local itemFrame = InventoryUI.Elements.ItemFrame:Clone()
				itemFrame.Visible = true
				itemFrame.LayoutOrder = -item.Rarity
				itemFrame.Name = name
				itemFrame.Icon.Image = icon
				itemFrame.Count.Text = `x{value.Count}`
				itemFrame.UIStroke.Color = rarity.Color
				itemFrame:AddTag("_UIItemFrame")
				itemFrame:AddTag("_UIItemTradable")
				itemFrame:SetAttribute(`Rarity`, item.Rarity)
				itemFrame:SetAttribute(`Category`, category)
				itemFrame:SetAttribute(`Level`, tostring(level))
				itemFrame:SetAttribute(`Id`, tostring(id))
				itemFrame:SetAttribute(`Count`, value.Count)
				itemFrame.Parent = InventoryUI.Main.Body.Inventory

				local button: TextButton = itemFrame.Button
				button.MouseMoved:Connect(function(x, y)
					Tooltip:Enable({
						Name = `{name} Lv.{level}`,
						Description = item.Description,
						Rarity = rarity,
						DropChance = item.DropChance,
						Position = UDim2.fromOffset(x, y),
						Category = category,
						Id = id,
					})
				end)
				button.MouseLeave:Connect(function()
					Tooltip:Disable()
				end)
			end
		end

		InventorySystem:Filter()
	end
end

--- Filter the items in the inventory and hide the ones that don't need to be shown
function InventorySystem:Filter()
	local text = InventoryUI.Main.Header.Filters.SearchBox.Text
	local length = string.len(text)
	local filters = Dictionary.count(InventorySystem._Filters, function(value)
		return value == true
	end)

	for _, frame in CollectionService:GetTagged("_UIItemFrame") do
		if length == 0 then
			frame.Visible = true
		else
			--- Filter by name
			if string.sub(string.lower(frame.Name), 1, length) == string.lower(text) then
				frame.Visible = true
			else
				frame.Visible = false
			end
		end

		--- Further filter by rarities
		if filters > 0 then
			local rarity = frame:GetAttribute("Rarity")
			local hasFilter = Dictionary.find(InventorySystem._Filters, function(value, key)
				if key == rarity and value == true then
					return true
				end

				return false
			end)

			if frame.Visible then
				if not hasFilter then
					frame.Visible = false
				end
			end
		end
	end
end

function InventorySystem:GetInventory()
	return InventorySystem._Inventory
end

function InventorySystem:SetInventory(inventory)
	InventorySystem._Inventory = inventory

	if InventorySystem._CurrentCategory then
		InventorySystem:OpenCategory(InventorySystem._CurrentCategory)
	end
end

function InventorySystem:SetInventorySpace(newValue: number)
	InventorySystem._MaximumInventory = newValue

	if InventorySystem._CurrentCategory then
		InventorySystem:OpenCategory(InventorySystem._CurrentCategory)
	end
end

--- Initialize the inventory system
local function Init()
	InventoryUI = Players.LocalPlayer.PlayerGui:WaitForChild("Inventory")
	InventoryUI.Main.Visible = false

	InventoryUI.Main:GetPropertyChangedSignal("Visible"):Connect(function()
		if InventoryUI.Main.Visible then
			local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			local rootPart = character.PrimaryPart

			if rootPart then
				DynamicDepth:Enable()
				DynamicDepth:SetDepthToPart(rootPart, nil, 2)
			end

			InventorySystem:OpenCategory(DEFAULT_CATEGORY_NAME)
		else
			InventorySystem._CurrentCategory = nil
			table.clear(InventorySystem._Filters)

			for _, frame in CollectionService:GetTagged("_UIItemRarityFilterButton") do
				frame.Icon.ImageTransparency = 1
			end

			InventoryUI.Main.Header.Filters.Filter.Info.Title.Text = `0 filters`
			DynamicDepth:Disable()
			Tooltip:Cleanup()
		end
	end)

	InventoryUI.Roll.MouseButton1Click:Connect(RequestLootDrop)

	InventoryUI.Bag.MouseButton1Click:Connect(function()
		InventoryUI.Main.Visible = not InventoryUI.Main.Visible
	end)

	InventoryUI.Main.Header.Close.MouseButton1Click:Connect(function()
		InventoryUI.Main.Visible = false
	end)

	InventoryUI.Main.Header.Filters.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		InventorySystem:Filter()
	end)

	InventoryUI.Main.Header.Filters.Filter.MouseButton1Click:Connect(function()
		local dropDown = InventoryUI.Main.Header.Filters.Filter.DropDown
		dropDown.Visible = not dropDown.Visible
	end)

	--- Create the categories
	for name, category in ItemData:GetCategories() do
		local button = InventoryUI.Elements.Category:Clone()
		button.Visible = true
		button.Title.Text = name
		button.Icon.Image = category.Icon or ""
		button.LayoutOrder = category.Order or 0
		button.Parent = InventoryUI.Main.Body.Categories

		button.MouseButton1Click:Connect(function()
			InventorySystem:OpenCategory(name)
		end)
	end

	--- Create the rarity filters
	for layoutOrder, rarityData in RarityReference do
		local button = InventoryUI.Elements.Filter:Clone()
		button.Visible = true
		button.Title.Text = rarityData.Name
		button.Title.TextColor3 = rarityData.Color
		button.LayoutOrder = layoutOrder
		button.Size = UDim2.fromScale(1, 1 / #RarityReference)
		button:AddTag("_UIItemRarityFilterButton")
		button.Parent = InventoryUI.Main.Header.Filters.Filter.DropDown

		button.MouseButton1Click:Connect(function()
			InventorySystem._Filters[layoutOrder] = not InventorySystem._Filters[layoutOrder]
			button.Icon.ImageTransparency = InventorySystem._Filters[layoutOrder] and 0 or 1

			local text = `{Dictionary.count(InventorySystem._Filters, function(value)
				return value == true
			end)} filters`

			InventoryUI.Main.Header.Filters.Filter.Info.Title.Text = text
			InventorySystem:Filter()
		end)
	end
end

Init()
return InventorySystem
