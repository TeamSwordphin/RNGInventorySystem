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

local Settings = require(ReplicatedStorage.Modules.GlobalSettings)
local ItemData = require(ReplicatedStorage.Modules.ItemData)
local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local Zap = require(ReplicatedStorage.Network.Zap)

local Tooltip = require(script.Parent.Tooltip)

local TradeUI
local Player = Players.LocalPlayer
local TradeJanitor = Janitor.new()

local TradeSystem = { _IsTradeEnabled = true, _ThumbnailCache = {} }

function TradeSystem:GetUserThumbnailAsync(userId: number)
	if not TradeSystem._ThumbnailCache[userId] then
		local content, isReady =
			Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

		TradeSystem._ThumbnailCache[userId] = isReady and content or ""
	end

	return TradeSystem._ThumbnailCache[userId]
end

function TradeSystem:Open()
	for _, ui in CollectionService:GetTagged("_UITradingComponent") do
		ui:Destroy()
	end

	for _, player in Players:GetPlayers() do
		if player:GetAttribute("IgnoreTradeRequests") then
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
	playerWidget.ThemFrame.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(inviter.UserId)
	playerWidget.ThemFrame.PlayerName.Text = inviter.DisplayName
	playerWidget.YouFrame.PlayerIcon.Image = TradeSystem:GetUserThumbnailAsync(recipient.UserId)
	playerWidget.YouFrame.PlayerName.Text = recipient.DisplayName
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
		no:Destroy()
		yes:Destroy()
		Zap.SendClientTradeCancel.Fire()
	end)

	yes.MouseButton1Click:Connect(function()
		playerWidget.Middle.ArrowRight.ImageColor3 = Color3.fromRGB(106, 211, 106)
		widget.Trading.Buttons.Message.Text = "Offer Accepted"
		widget.Trading.Buttons.Message.Visible = true
		yes.Visible = false
	end)

	local function onItemFrameClicked(itemFrame)
		local button = itemFrame:WaitForChild("Button", 10)

		if not button then
			return
		end

		button.MouseButton1Click:Connect(function()
			local frame = playerWidget.YouFrame.PlayerIcon:FindFirstChildOfClass("Frame")

			local clone = itemFrame:Clone()
			clone:RemoveTag("_UIItemFrame")
			clone:AddTag("_UITradingComponentInvite")
			clone.Count.Visible = false
			clone.Position = UDim2.fromScale(1, 1)
			clone.Size = UDim2.fromScale(0.8, 0.8)
			clone.AnchorPoint = Vector2.new(0.5, 1)
			clone.Parent = playerWidget.YouFrame.PlayerIcon

			local reference = ItemData:GetCategory(clone:GetAttribute("Category"))
			local item = reference:GetItem(clone:GetAttribute("Id"))
			local rarity = RarityReference[item.Rarity]
			local button: TextButton = clone.Button

			button.MouseMoved:Connect(function(x, y)
				Tooltip:Enable({
					Name = `{clone.Name} Lv.{clone:GetAttribute("Level")}`,
					Description = item.Description,
					Rarity = rarity,
					DropChance = item.DropChance,
					Position = UDim2.fromOffset(x, y),
					Category = clone:GetAttribute("Category"),
					Id = clone:GetAttribute("Id"),
				})
			end)
			button.MouseLeave:Connect(function()
				Tooltip:Disable()
			end)

			Zap.ClientSentItemTradeOffer.Fire({
				category = clone:GetAttribute("Category"),
				id = clone:GetAttribute("Id"),
				level = clone:GetAttribute("Level"),
			})

			yes.Visible = true

			if frame then
				frame:Destroy()
			end
		end)
	end

	for _, button in CollectionService:GetTagged("_UIItemTradable") do
		onItemFrameClicked(button)
	end

	TradeJanitor:Add(CollectionService:GetInstanceAddedSignal("_UIItemTradable"):Connect(onItemFrameClicked))

	-- Open Inventory
	TradeUI.Main.Visible = false
	Player.PlayerGui.Inventory.Main.Visible = true
end)

--- Listen for item offer changes. Purely visual.
Zap.ServerSentItemTradeOffer.On(function(data: { category: string, id: number, level: number })
	local category = data.category
	local id = data.id
	local level = data.level

	local reference = ItemData:GetCategory(category)
	local item = reference:GetItem(id)
	local name = item.Name
	local icon = item.Icon
	local rarity = RarityReference[item.Rarity]

	local widget = TradeUI.TradeWidget
	local playerWidget = widget.Trading.Players
	local frame = playerWidget.ThemFrame.PlayerIcon:FindFirstChildOfClass("Frame")

	local clone = Player.PlayerGui.Inventory.Elements.ItemFrame:Clone()
	clone:AddTag("_UITradingComponentInvite")
	clone:RemoveTag("_UIItemFrame")
	clone.Count.Visible = false
	clone.Visible = true
	clone.Name = name
	clone.Icon.Image = icon
	clone.UIStroke.Color = rarity.Color
	clone.Position = UDim2.fromScale(0, 1)
	clone.Size = UDim2.fromScale(0.8, 0.8)
	clone.AnchorPoint = Vector2.new(0.5, 1)
	clone.Parent = playerWidget.ThemFrame.PlayerIcon

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

	if frame then
		frame:Destroy()
	end
end)

--- Listen to trade cancel requests
Zap.OnServerTradeCancel.On(function()
	for _, ui in CollectionService:GetTagged("_UITradingComponentInvite") do
		ui:Destroy()
	end

	TradeJanitor:Cleanup()

	local widget = TradeUI.TradeWidget
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

	TradeUI.Trade.MouseButton1Click:Connect(function()
		if TradeSystem._IsTradeEnabled then
			TradeUI.Main.Visible = not TradeUI.Main.Visible
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		TradeSystem._ThumbnailCache[player.UserId] = nil
	end)
end

Init()
return TradeSystem
