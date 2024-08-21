--[[

	Handles the creation and management of the inventory system.

	@author Phin 2024

]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DynamicDepth = require(ReplicatedStorage.Libraries.DynamicDepth)

local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local PotionData = require(ReplicatedStorage.Modules.PotionData)

local Zap = require(ReplicatedStorage.Network.Zap)

local StatusEffectManager = require(script.Parent.StatusEffectIndicators)
local Tooltip = require(script.Parent.Tooltip)

local InventoryUI

local PotionInventorySystem = { _Inventory = nil }

--- Opens and updates the UI within.
function PotionInventorySystem:Open()
	local inventory = PotionInventorySystem._Inventory or {}
	local reference = PotionData:GetPotionList()

	--- Clear out older item frames
	for _, frame in CollectionService:GetTagged("_UIPotionItemFrame") do
		frame:Destroy()
	end

	--- Create the new ui frames

	for id, count in inventory do
		if count < 1 then
			continue
		end

		local item = reference[tonumber(id)]

		if not item then
			continue
		end

		local name = item.Name
		local icon = item.Icon
		local rarity = RarityReference[item.Rarity]

		local itemFrame = InventoryUI.Elements.ItemFrame:Clone()
		local countLabel = itemFrame.Count

		countLabel.Text = `x{count}`
		itemFrame.Visible = true
		itemFrame.LayoutOrder = -item.Rarity
		itemFrame.Name = name
		itemFrame.Icon.Image = icon
		itemFrame.UIStroke.Color = rarity.Color
		itemFrame:AddTag("_UIPotionItemFrame")
		itemFrame:SetAttribute(`Rarity`, item.Rarity)
		itemFrame:SetAttribute(`Id`, tostring(id))
		itemFrame.Parent = InventoryUI.Main.Body.Inventory

		local button: TextButton = itemFrame.Button
		local useButton: TextButton = itemFrame.Use
		useButton:AddTag("_UIPotionItemFrameUseButton")

		button.MouseMoved:Connect(function(x, y)
			Tooltip:Enable({
				Name = `{name}`,
				Description = `{item.Description}\n\nDuration: {item.Duration}s`,
				Rarity = rarity,
				Position = UDim2.fromOffset(x, y),
				Id = id,
			})
		end)
		button.MouseLeave:Connect(function()
			Tooltip:Disable()
		end)
		button.MouseButton1Click:Connect(function()
			for _, ui in CollectionService:GetTagged("_UIPotionItemFrameUseButton") do
				ui.Visible = false
			end

			useButton.Visible = true
		end)

		useButton.MouseButton1Click:Connect(function()
			local data = Zap.ClientRequestPotionActivate.Call(id)

			if data.success then
				if count > 0 then
					count -= 1
					countLabel.Text = `x{count}`

					local statusEffect: StatusEffectManager.StatusEffect = {
						Id = id,
						Image = icon,
						Duration = item.Duration,
						Rolls = item.Rolls,
					}

					StatusEffectManager:Add(statusEffect)
				end
			end

			if count < 1 then
				itemFrame:Destroy()
				Tooltip:Disable()
			end
		end)
	end
end

function PotionInventorySystem:GetInventory()
	return PotionInventorySystem._Inventory
end

function PotionInventorySystem:SetInventory(inventory)
	PotionInventorySystem._Inventory = inventory

	if InventoryUI.Main.Visible then
		PotionInventorySystem:Open()
	end
end

--- Initialize the inventory system
local function Init()
	InventoryUI = Players.LocalPlayer.PlayerGui:WaitForChild("PotionManager")
	InventoryUI.Main.Visible = false

	InventoryUI.Main:GetPropertyChangedSignal("Visible"):Connect(function()
		if InventoryUI.Main.Visible then
			local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			local rootPart = character.PrimaryPart

			if rootPart then
				DynamicDepth:Enable()
				DynamicDepth:SetDepthToPart(rootPart, nil, 2)
			end

			PotionInventorySystem:Open()
		else
			DynamicDepth:Disable()
			Tooltip:Cleanup()
		end
	end)

	InventoryUI.Bag.MouseButton1Click:Connect(function()
		InventoryUI.Main.Visible = not InventoryUI.Main.Visible
	end)

	InventoryUI.Main.Header.Close.MouseButton1Click:Connect(function()
		InventoryUI.Main.Visible = false
	end)
end

Init()
return PotionInventorySystem
