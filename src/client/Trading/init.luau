--[[

	Handles the interface management of trading.

	@author Phin 2024

]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local DynamicDepth = require(ReplicatedStorage.Libraries.DynamicDepth)
local Janitor = require(ReplicatedStorage.Libraries.Janitor)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local List = Freeze.List

local Settings = require(ReplicatedStorage.Modules.GlobalSettings)
local ItemData = require(ReplicatedStorage.Modules.ItemData)
local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local Zap = require(ReplicatedStorage.Network.Zap)

local Tooltip = require(script.Parent.Tooltip)

local TradeUI
local Player = Players.LocalPlayer
local TradeJanitor = Janitor.new()

local TradeSystem = { _IsTradeEnabled = false, _ThumbnailCache = {} }

function TradeSystem:SetTradeEnabled(new: boolean)
	TradeSystem._IsTradeEnabled = new

	if new == true then
		TradeUI.Trade.ImageColor3 = Color3.fromRGB(255, 255, 255)
		TradeUI.Trade.Title.TextColor3 = Color3.fromRGB(240, 255, 251)
	end
end

function TradeSystem:GetUserThumbnailAsync(userId: number)
	if userId <= 1 then
		userId = 297701
	end

	if not TradeSystem._ThumbnailCache[userId] then
		local thumbnailType = Enum.ThumbnailType.HeadShot
		local thumbnailSize = Enum.ThumbnailSize.Size420x420
		local content, isReady = Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)

		TradeSystem._ThumbnailCache[userId] = isReady and content or ""
	end

	return TradeSystem._ThumbnailCache[userId]
end

function TradeSystem:Open()
	for _, ui in CollectionService:GetTagged("_UITradingComponent") do
		ui:Destroy()
	end

	for _, player in Players:GetPlayers() do
		if player == Player or player:GetAttribute("IgnoreTradeRequests") then
			continue
		end

		task.defer(function()
			local component = TradeUI.Elements.PlayerTradeSelection:Clone()
			component:AddTag("_UITradingComponent")
			component.Visible = true
			component.Parent = TradeUI.Main.Body

			if component.Parent ~= nil then
				component.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(player.UserId)
				component.Sidebar.PlayerName.Text = player.DisplayName
				component.Sidebar.Trade.Visible = true

				component.Sidebar.Trade.MouseButton1Click:Connect(function()
					Zap.SendPlayerTradeRequest.Fire(player)
				end)

				return
			end

			component:Destroy()
		end)
	end
end

--- Listen for when the player gets invited to trade
Zap.OnPlayerTradeRequest.On(function(inviter: Player)
	if not inviter:IsDescendantOf(Players) then
		return
	end

	for _, ui in CollectionService:GetTagged("_UITradingComponentInvite") do
		ui:Destroy()
	end

	local widget = TradeUI.TradeWidget
	widget.Position = UDim2.fromScale(-1, 0.5)
	widget.Inviting.PlayerFrame.PlayerName.Text = `<b>{inviter.DisplayName}</b> wants to trade!`
	widget.Inviting.PlayerFrame.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(inviter.UserId)
	widget.Inviting.Bar.InnerBar.Size = UDim2.fromScale(1, 1)
	widget.Inviting.Visible = true
	widget.Trading.Visible = false
	widget.Visible = true

	local info = TweenInfo.new(1, Enum.EasingStyle.Back)
	local tween = TweenService:Create(widget, info, { Position = UDim2.fromScale(0, 0.5) })
	tween:Play()

	local no = TradeUI.Elements.No:Clone()
	no:AddTag("_UITradingComponentInvite")
	no.Visible = true
	no.Parent = widget.Inviting.Buttons

	local yes = TradeUI.Elements.Yes:Clone()
	yes:AddTag("_UITradingComponentInvite")
	yes.Visible = true
	yes.Parent = widget.Inviting.Buttons

	local timeoutTween = TweenInfo.new(Settings.Trading_Cooldown, Enum.EasingStyle.Linear)
	local timeoutBar = TweenService:Create(widget.Inviting.Bar.InnerBar, timeoutTween, { Size = UDim2.fromScale(0, 1) })
	local endTween = TweenService:Create(widget, info, { Position = UDim2.fromScale(-1, 0.5) })
	local accepted = false

	no.MouseButton1Click:Connect(function()
		timeoutBar:Cancel()
	end)

	yes.MouseButton1Click:Connect(function()
		accepted = true
		timeoutBar:Cancel()
		Zap.AcceptPlayerTradeRequest.Fire(inviter)
	end)

	timeoutBar:Play()
	timeoutBar.Completed:Wait()

	if not accepted and not widget.Trading.Visible then
		endTween:Play()
	end
end)

--- Listen for when trading finally starts
Zap.OnServerTradeBegun.On(function(data: { inviter: Player, recipient: Player })
	local inviter = data.inviter
	local recipient = data.recipient

	if not inviter:IsDescendantOf(Players) then
		return
	end

	for _, ui in CollectionService:GetTagged("_UITradingComponentInvite") do
		ui:Destroy()
	end

	TradeJanitor:Cleanup()

	-- Create trading menu
	local widget = TradeUI.TradeWidget
	widget.Inviting.Visible = false
	widget.Trading.Visible = true
	widget.Trading.Buttons.Message.Visible = false
	widget.Trading.Bar.InnerBar.Size = UDim2.fromScale(0, 1)
	widget.Visible = true

	local playerWidget = widget.Trading.Players
	playerWidget.ThemFrame.Player.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(inviter.UserId)
	playerWidget.ThemFrame.Player.PlayerName.Text = inviter.DisplayName
	playerWidget.YouFrame.Player.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(recipient.UserId)
	playerWidget.YouFrame.Player.PlayerName.Text = recipient.DisplayName
	playerWidget.Middle.ArrowLeft.ImageColor3 = Color3.fromRGB(255, 255, 255)
	playerWidget.Middle.ArrowRight.ImageColor3 = Color3.fromRGB(255, 255, 255)

	local info = TweenInfo.new(1, Enum.EasingStyle.Back)
	local tween = TweenService:Create(widget, info, { Position = UDim2.fromScale(0, 0.5) })
	tween:Play()

	local no = TradeUI.Elements.No:Clone()
	no:AddTag("_UITradingComponentInvite")
	no.Visible = true
	no.Parent = widget.Trading.Buttons

	local yes = TradeUI.Elements.Yes:Clone()
	yes:AddTag("_UITradingComponentInvite")
	yes.Visible = false
	yes.Parent = widget.Trading.Buttons

	no.MouseButton1Click:Connect(function()
		TradeJanitor:Cleanup()
		no:Destroy()
		yes:Destroy()
		Zap.SendClientTradeCancel.Fire()
	end)

	yes.MouseButton1Click:Connect(function()
		TradeJanitor:Cleanup()
		playerWidget.Middle.ArrowRight.ImageColor3 = Color3.fromRGB(106, 211, 106)
		widget.Trading.Buttons.Message.Text = "Offer Accepted"
		widget.Trading.Buttons.Message.Visible = true
		yes.Visible = false
		Zap.ClientAcceptTradeOffer.Fire()
	end)

	local items = {}

	local function onItemFrameClicked(itemFrame)
		local button = itemFrame:WaitForChild("Button", 10)

		if not button then
			return
		end

		TradeJanitor:Add(button.MouseButton1Click:Connect(function()
			local category = itemFrame:GetAttribute("Category")
			local id = itemFrame:GetAttribute("Id")
			local level = itemFrame:GetAttribute("Level")

			local ifExists = List.find(items, function(data)
				if data.level == level and data.id == id and data.category == category then
					return true
				end

				return false
			end)

			local clone

			if ifExists then
				if ifExists.count < ifExists.button:GetAttribute("Count") then
					ifExists.count += 1
				end

				clone = ifExists.button
			else
				clone = itemFrame:Clone()
				clone:RemoveTag("_UIItemFrame")
				clone:AddTag("_UITradingComponentInvite")
				clone.Position = UDim2.fromScale(1, 1)
				clone.Size = UDim2.fromScale(0.8, 0.8)
				clone.AnchorPoint = Vector2.new(0.5, 1)
				clone.Parent = playerWidget.YouFrame.Inventory

				ifExists = { category = category, id = id, level = level, count = 1, button = clone }

				table.insert(items, ifExists)
			end

			clone.Count.Text = `x{ifExists.count}`

			local reference = ItemData:GetCategory(category)
			local item = reference:GetItem(id)
			local rarity = RarityReference[item.Rarity]
			local button: TextButton = clone.Button

			button.MouseMoved:Connect(function(x, y)
				Tooltip:Enable({
					Name = `{clone.Name} Lv.{level}`,
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

			Zap.ClientSentItemTradeOffer.Fire({
				category = category,
				id = id,
				level = level,
			})

			yes.Visible = true
		end))
	end

	for _, button in CollectionService:GetTagged("_UIItemTradable") do
		onItemFrameClicked(button)
	end

	TradeJanitor:Add(CollectionService:GetInstanceAddedSignal("_UIItemTradable"):Connect(onItemFrameClicked))

	-- Open Inventory
	TradeUI.Main.Visible = false
	Player.PlayerGui.Inventory.Main.Visible = true
end)

--- Listen for item offer changes from the recipient. Purely visual.
Zap.ServerSentItemTradeOffer.On(function(datas: { Zap.TradeData })
	for _, ui in CollectionService:GetTagged("_UITradingItem") do
		ui:Destroy()
	end

	for index, data in datas do
		local category = data.category
		local id = data.id
		local level = data.level
		local count = data.count or 1

		local reference = ItemData:GetCategory(category)
		local item = reference:GetItem(id)
		local name = item.Name
		local icon = item.Icon
		local rarity = RarityReference[item.Rarity]

		local widget = TradeUI.TradeWidget
		local playerWidget = widget.Trading.Players

		local clone = Player.PlayerGui.Inventory.Elements.ItemFrame:Clone()
		clone:AddTag("_UITradingComponentInvite")
		clone:AddTag("_UITradingItem")
		clone:RemoveTag("_UIItemFrame")
		clone.Count.Text = `x{count}`
		clone.Visible = true
		clone.Name = name
		clone.Icon.Image = icon
		clone.UIStroke.Color = rarity.Color
		clone.Position = UDim2.fromScale(0, 1)
		clone.Size = UDim2.fromScale(0.8, 0.8)
		clone.AnchorPoint = Vector2.new(0.5, 1)
		clone.Parent = playerWidget.ThemFrame.Inventory

		local button: TextButton = clone.Button
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
end)

--- Listen for the recipient to accept the trade offer
Zap.ServerSentAcceptTradeOffer.On(function()
	local widget = TradeUI.TradeWidget
	local playerWidget = widget.Trading.Players
	playerWidget.Middle.ArrowLeft.ImageColor3 = Color3.fromRGB(106, 211, 106)
end)

--- Listen if both parties have agreed to this trade
Zap.BothPartiesAcceptedTradeOffer.On(function()
	TradeJanitor:Add(task.defer(function()
		local widget = TradeUI.TradeWidget

		for i = 3, 1, -1 do
			widget.Trading.Buttons.Message.Text = `Trading in... {i}`
			widget.Trading.Buttons.Message.Visible = true
			task.wait(1)
		end

		widget.Trading.Buttons.Message.Text = `Traded success!`
		task.wait(3)
		widget.Visible = false
	end))
end)

--- Listen to trade cancel requests
Zap.OnServerTradeCancel.On(function()
	for _, ui in CollectionService:GetTagged("_UITradingComponentInvite") do
		ui:Destroy()
	end

	TradeJanitor:Cleanup()

	local widget = TradeUI.TradeWidget
	widget.Visible = false
	widget.Visible = true
	widget.Trading.Buttons.Message.Text = "Trade Cancelled!"
	widget.Trading.Buttons.Message.Visible = true

	task.wait(3)

	widget.Visible = false
end)

--- Initialize the craft menu system
local function Init()
	TradeUI = Player.PlayerGui:WaitForChild("TradeMenu")
	TradeUI.Main.Visible = false
	TradeUI.TradeWidget.Visible = false

	TradeUI.Main:GetPropertyChangedSignal("Visible"):Connect(function()
		if TradeUI.Main.Visible then
			local character = Player.Character or Player.CharacterAdded:Wait()
			local rootPart = character.PrimaryPart

			if rootPart then
				DynamicDepth:Enable()
				DynamicDepth:SetDepthToPart(rootPart, nil, 2)
			end

			TradeSystem:Open()
		else
			DynamicDepth:Disable()
			Tooltip:Cleanup()
		end
	end)

	TradeUI.Main.Header.Close.MouseButton1Click:Connect(function()
		TradeUI.Main.Visible = false
	end)

	local _purchaseText = TradeUI.PurchaseTradeOption.Message.Text

	TradeUI.Trade.MouseButton1Click:Connect(function()
		if TradeSystem._IsTradeEnabled then
			TradeUI.Main.Visible = not TradeUI.Main.Visible
		else
			-- Run purchase prompt
			TradeUI.PurchaseTradeOption.Message.Text = _purchaseText
			TradeUI.PurchaseTradeOption.Visible = true
		end
	end)

	TradeUI.Main.Header.IgnoreRequest.MouseButton1Click:Connect(function()
		Zap.ClientToggleIgnoreTradeRequest.Fire()
	end)

	TradeUI.PurchaseTradeOption.Buttons.No.MouseButton1Click:Connect(function()
		TradeUI.PurchaseTradeOption.Visible = false
	end)

	TradeUI.PurchaseTradeOption.Buttons.Yes.MouseButton1Click:Connect(function()
		local data = Zap.ClientPurchaseTradeFeature.Call()
		local success = data.success

		if success then
			TradeUI.PurchaseTradeOption.Visible = false
		else
			TradeUI.PurchaseTradeOption.Message.Text = "Not enough Money!"
		end
	end)

	local function onTradeToggleChanged()
		local toggle = not Player:GetAttribute("IgnoreTradeRequests")

		TradeUI.Main.Header.IgnoreRequest.Icon.ImageTransparency = toggle and 0 or 1
		TradeUI.Main.Header.IgnoreRequest.Title.TextColor3 = toggle and Color3.fromRGB(71, 167, 69)
			or Color3.fromRGB(65, 72, 62)
	end

	onTradeToggleChanged()
	Player:GetAttributeChangedSignal("IgnoreTradeRequests"):Connect(onTradeToggleChanged)

	Players.PlayerRemoving:Connect(function(player: Player)
		TradeSystem._ThumbnailCache[player.UserId] = nil
	end)
end

Init()
return TradeSystem
