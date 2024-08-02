--[[

	Handles the creation and management of the craft system.

	@author Phin 2024

]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DynamicDepth = require(ReplicatedStorage.Libraries.DynamicDepth)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local List = Freeze.List

local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local CraftData = require(ReplicatedStorage.Modules.CraftData)
local ItemData = require(ReplicatedStorage.Modules.ItemData)
local Zap = require(ReplicatedStorage.Network.Zap)

local CraftUI

local CraftSystem = { _CraftProgress = nil, _AutoRollIndex = nil, _CurrentOpenedCraftIndex = 0 }

--- Opens the category and updates the UI within.
-- @param category: string -> the category name to open
function CraftSystem:Open()
	local craftList = CraftData:GetCraftingList()
	local progress = CraftSystem._CraftProgress

	--- Clear out older item frames
	for _, frame in CollectionService:GetTagged("_UIItemFrame") do
		frame:Destroy()
	end

	--- Create the new ui frames
	for i, craftData in craftList do
		local currentProgress = progress[tostring(i)] or {}
		local name = craftData.Name
		local description = craftData.Description

		local craftMain = CraftUI.Elements.CraftElement:Clone()
		craftMain.Visible = true
		craftMain.LayoutOrder = currentProgress.Completed and 999 or i
		craftMain.Details.Title.Text = name
		craftMain.Details.Description.Text = description
		craftMain:AddTag("_UIItemFrame")
		craftMain:AddTag("_UICraftMain")
		craftMain.Parent = CraftUI.Main.CraftList

		local function adjustAutoRoller()
			craftMain.UIStroke.Color = CraftSystem._AutoRollIndex == i and Color3.fromRGB(185, 124, 255)
				or CraftUI.Elements.CraftElement.UIStroke.Color
		end

		local function checkRecipeCompletion()
			if currentProgress.Completed then
				craftMain.Completed.Visible = true
			end
		end

		adjustAutoRoller()
		checkRecipeCompletion()

		if not craftMain.Completed.Visible then
			local function openCraft()
				CraftSystem._CurrentOpenedCraftIndex = i

				for _, frame in CollectionService:GetTagged("_UICraftInner") do
					frame:Destroy()
				end

				for _, recipe in craftData.Recipe do
					local category = recipe.Category
					local id = recipe.Id
					local level = recipe.Level or 1

					local element = List.find(currentProgress, function(value)
						if value.Category == category and value.Id == id and value.Level == level then
							return true
						end

						return
					end) or { Count = 0 }

					local reference = ItemData:GetCategory(category)
					local item = reference:GetItem(id)
					local rarity = RarityReference[item.Rarity]

					local material = CraftUI.Elements.Material:Clone()
					material.Visible = true
					material.LayoutOrder = item.Rarity
					material.WorkList.Title.TextColor3 = rarity.Color
					material.WorkList.Title.Text = `{item.Name} Lv.{level}`
					material.WorkList.Required.Text = `{element.Count} / {recipe.Count}`
					material:AddTag("_UICraftInner")
					material:AddTag("_UIItemFrame")
					material.Parent = CraftUI.Main.Body.MaterialList

					if element.Count >= recipe.Count then
						material.Completed.Visible = true
						material.WorkList.Add.Interactable = false
						material.WorkList.Amount.Interactable = false
					end

					if not material.Completed.Visible then
						material.WorkList.Add.MouseButton1Click:Connect(function()
							local amount = math.min(recipe.Count, tonumber(material.WorkList.Amount.Text) or 1)
							local data = Zap.AddItemToCraftIngredient.Call({
								craftIndex = i,
								category = category,
								id = id,
								level = level,
								amount = amount,
							})

							local success, count = data.success, data.count
							if success then
								element.Count = count
							end
						end)
					end
				end

				if not currentProgress.Completed then
					local craft = CraftUI.Elements.Craft:Clone()
					craft.Visible = true
					craft:AddTag("_UICraftInner")
					craft:AddTag("_UIItemFrame")
					craft.Parent = CraftUI.Main.Body.Buttons

					local auto = CraftUI.Elements.Auto:Clone()
					auto.Visible = true
					auto:AddTag("_UICraftInner")
					auto:AddTag("_UIItemFrame")
					auto.Parent = CraftUI.Main.Body.Buttons

					auto.UIStroke.Color = CraftSystem._AutoRollIndex == i and Color3.fromRGB(185, 124, 255)
						or CraftUI.Elements.Auto.UIStroke.Color

					craft.MouseButton1Click:Connect(function()
						local data = Zap.CraftItem.Call(i)
						local success = data.success

						print(`Craft status:`, success)

						if success then
							currentProgress.Completed = true
							craft:Destroy()
							auto:Destroy()
							checkRecipeCompletion()
						end
					end)

					auto.MouseButton1Click:Connect(function()
						if CraftSystem._AutoRollIndex == i then
							CraftSystem._AutoRollIndex = 0
							Zap.SendAutoRollIndex.Fire(0)
						else
							CraftSystem._AutoRollIndex = i
							Zap.SendAutoRollIndex.Fire(i)
						end

						auto.UIStroke.Color = CraftSystem._AutoRollIndex == i and Color3.fromRGB(185, 124, 255)
							or CraftUI.Elements.Auto.UIStroke.Color

						for _, item in CollectionService:GetTagged("_UICraftMain") do
							item.UIStroke.Color = CraftUI.Elements.CraftElement.UIStroke.Color
						end

						adjustAutoRoller()
					end)
				end
			end

			craftMain.MouseEnter:Connect(openCraft)

			if CraftSystem._CurrentOpenedCraftIndex == i then
				openCraft()
			end
		end
	end
end

function CraftSystem:OpenBuffList()
	local craftList = CraftData:GetCraftingList()
	local progress = CraftSystem._CraftProgress

	--- Clear out older item frames
	for _, frame in CollectionService:GetTagged("_UIItemFrame") do
		frame:Destroy()
	end

	local unlocked = List.filter(craftList, function(_, craftIndex)
		craftIndex = tostring(craftIndex)

		if progress[craftIndex] then
			if progress[craftIndex].Completed then
				return true
			end
		end

		return
	end)

	--- Create the new ui frames
	for i, craftData in unlocked do
		local name = craftData.Name
		local description = craftData.Description

		local craftMain = CraftUI.Elements.CraftElement:Clone()
		craftMain.Visible = true
		craftMain.LayoutOrder = i
		craftMain.Details.Title.Text = name
		craftMain.Details.Description.Text = description
		craftMain:AddTag("_UIItemFrame")
		craftMain:AddTag("_UICraftMain")
		craftMain.Parent = CraftUI.BuffList.Body
	end
end

function CraftSystem:SetCraftProgress(newProgress)
	CraftSystem._CraftProgress = newProgress
	task.defer(CraftSystem.Open, CraftSystem)
end

function CraftSystem:SetAutoRollIndex(index)
	CraftSystem._AutoRollIndex = index
end

--- Initialize the craft menu system
local function Init()
	CraftUI = Players.LocalPlayer.PlayerGui:WaitForChild("CraftMenu")
	CraftUI.Main.Visible = false

	CraftUI.Main:GetPropertyChangedSignal("Visible"):Connect(function()
		if CraftUI.Main.Visible then
			local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			local rootPart = character.PrimaryPart

			if rootPart then
				DynamicDepth:Enable()
				DynamicDepth:SetDepthToPart(rootPart, nil, 2)
			end

			CraftSystem:Open()
		else
			CraftSystem._CurrentOpenedCraftIndex = 0
			DynamicDepth:Disable()
		end
	end)

	CraftUI.BuffList:GetPropertyChangedSignal("Visible"):Connect(function()
		if CraftUI.BuffList.Visible then
			local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
			local rootPart = character.PrimaryPart

			if rootPart then
				DynamicDepth:Enable()
				DynamicDepth:SetDepthToPart(rootPart, nil, 2)
			end

			CraftSystem:OpenBuffList()
		else
			DynamicDepth:Disable()
		end
	end)

	CraftUI.Main.Body.Header.Close.MouseButton1Click:Connect(function()
		CraftUI.Main.Visible = false
	end)

	CraftUI.BuffList.Header.Close.MouseButton1Click:Connect(function()
		CraftUI.BuffList.Visible = false
	end)

	CraftUI.Buffs.MouseButton1Click:Connect(function()
		CraftUI.BuffList.Visible = not CraftUI.BuffList.Visible
	end)

	for _, proximityPrompt in CollectionService:GetTagged("CraftPrompt") do
		proximityPrompt.Triggered:Connect(function()
			CraftUI.Main.Visible = true
		end)
	end

	CollectionService:GetInstanceAddedSignal("CraftPrompt"):Connect(function(proximityPrompt: ProximityPrompt)
		proximityPrompt.Triggered:Connect(function()
			CraftUI.Main.Visible = true
		end)
	end)
end

Init()
return CraftSystem
