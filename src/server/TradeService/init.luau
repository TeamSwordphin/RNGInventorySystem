--[[

	Handles trading systems. There will be a lot of redundancies to ensure security is thorough as possible.

	@author Phin 2024

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DropData = require(ReplicatedStorage.Modules.DropData)
local Settings = require(ReplicatedStorage.Modules.GlobalSettings)
local ProfileService = require(ReplicatedStorage.Libraries.ProfileService)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local List = Freeze.List

local Zap = require(ServerScriptService.Network.Zap)
local PlayerData = require(ServerScriptService.ServerSystems.PlayerDataService)

local TradeService = { _RecentlyInvited = {}, _CurrentlyTrading = {}, _LastOutageTime = -9999 }

function TradeService:CancelTrade(player: Player, doNotFire: boolean?)
	if TradeService._CurrentlyTrading[player] then
		-- Send cancel command
		if doNotFire == nil then
			Zap.OnServerTradeCancel.Fire(player)
		end

		-- Cancel any recipients connected to this player
		local recipient = TradeService._CurrentlyTrading[player].Recipient
		TradeService._CurrentlyTrading[player] = nil -- Nil this first so it doesn't infinitely loop
		TradeService:CancelTrade(recipient, doNotFire)

		-- Put them on mild cooldown right after cancellation
		TradeService._RecentlyInvited[player] = {
			LastTradeRequestTime = os.clock() - (Settings.Trading_Cooldown * 0.6),
			InvitedFrom = player,
		}
	end
end

--- Sanity check their saves to ensure that they have this item
function TradeService:SanityCheckForItem(
	player: Player,
	data: { category: string, id: number, level: number },
	count: number?
)
	local category = data.category
	local id = data.id
	local level = data.level

	local inventory = PlayerData:Get(player, "Inventory")

	if not inventory[category] then
		print(inventory)
		error(`No category of {category} was found in {player.Name}'s profile!`)
		return
	end

	local item = inventory[category][tostring(id)]

	if not item then
		print(inventory[category])
		error(`No item id in {category} of {id} was found in {player.Name}'s profile!`)
		return
	end

	local levelString = tostring(level)
	local numberedItem = item[levelString]

	if not numberedItem then
		print(item)
		error(`No item with the level {level} in {category} of {id} was found in {player.Name}'s profile!`)
		return
	end

	if numberedItem.Count < (count or 1) then
		print(numberedItem)
		error(`Item is lower than the required count!`)
		return
	end

	return numberedItem, item, levelString
end

--- Listens for outbound trade requests from players
Zap.SendPlayerTradeRequest.On(function(player: Player, recipient: Player)
	assert(recipient ~= nil, `recipient must not be nil!`)
	assert(recipient:IsA("Player"), `recipient must be a player!`)
	assert(recipient ~= player, `Player cannot request trade on themselves!`)

	-- Make sure the player is not in another trade
	if TradeService._CurrentlyTrading[player] then
		warn(`Player must not be in a trade!`)
		return
	end

	-- Make sure the recipient is not ignoring invites or are in another trade
	if recipient:GetAttribute("IgnoreTradeRequests") or TradeService._CurrentlyTrading[recipient] then
		warn(`Player Requested must not be in a trade or has their invites disabled!`)
		return
	end

	-- Check if the recipient has been recently invited to a trade from a player. Has a cooldown so two players can't
	-- simultaneously trade invite the same player
	if TradeService._RecentlyInvited[recipient] then
		local cooldown = (os.clock() - TradeService._RecentlyInvited[recipient].LastTradeRequestTime)

		if cooldown <= Settings.Trading_Cooldown then
			warn("This recipient was recently trade requested by another player")
			return
		end
	end

	local hostProfile = PlayerData:GetProfile(player)
	local recipientProfile = PlayerData:GetProfile(recipient)

	-- Ensure both profiles are loaded in the game
	if not hostProfile or not recipientProfile then
		warn(`One or more players do not have their profiles loaded!`)
		return
	end

	-- Ensure both profiles have trading unlocked!
	if not hostProfile.Data.TradeUnlocked or not recipientProfile.Data.TradeUnlocked then
		warn(`One or more players do not have trading unlocked yet!`)
		return
	end

	-- Track the recipient status
	TradeService._RecentlyInvited[recipient] = {
		LastTradeRequestTime = os.clock(),
		InvitedFrom = player,
	}

	-- Send trade request notifier to the recipient
	Zap.OnPlayerTradeRequest.Fire(recipient, player)
end)

--- Listens for accepted trade requests from players
Zap.AcceptPlayerTradeRequest.On(function(recipient: Player, inviter: Player)
	assert(inviter ~= nil, `inviter must not be nil!`)
	assert(inviter:IsA("Player"), `inviter must be a player!`)
	assert(recipient ~= inviter, `Player cannot request trade on themselves!`)

	local recentInvitedStatus = TradeService._RecentlyInvited[recipient]

	if not recentInvitedStatus then
		warn(`No recipient with this player object was recently invited to trade!`)
		return
	end

	if recentInvitedStatus.InvitedFrom ~= inviter then
		warn(`The inviter given is different to the one saved!`)
		return
	end

	if os.clock() - recentInvitedStatus.LastTradeRequestTime > Settings.Trading_Cooldown then
		warn(`This trade request has expired!`)
		return
	end

	-- Make sure the player is not in another trade
	if TradeService._CurrentlyTrading[inviter] then
		warn(`Player must not be in a trade!`)
		return
	end

	-- Make sure the recipient is not in another trade
	if TradeService._CurrentlyTrading[recipient] then
		warn(`Player Requested must not be in a trade!`)
		return
	end

	local hostProfile = PlayerData:GetProfile(inviter)
	local recipientProfile = PlayerData:GetProfile(recipient)

	-- Ensure both profiles are loaded in the game
	if not hostProfile or not recipientProfile then
		warn(`One or more players do not have their profiles loaded!`)
		return
	end

	-- Ensure both profiles have trading unlocked!
	if not hostProfile.Data.TradeUnlocked or not recipientProfile.Data.TradeUnlocked then
		warn(`One or more players do not have trading unlocked yet!`)
		return
	end

	-- Setup trading variables
	TradeService._CurrentlyTrading[inviter] = {
		Recipient = recipient,
		Accepted = false,
		Items = {},
	}

	TradeService._CurrentlyTrading[recipient] = {
		Recipient = inviter,
		Accepted = false,
		Items = {},
	}

	TradeService._RecentlyInvited[recipient] = nil
	TradeService._RecentlyInvited[inviter] = nil

	-- Update the Trading UI on both players
	Zap.OnServerTradeBegun.FireList({ recipient, inviter }, { inviter = inviter, recipient = recipient })
end)

--- Listen for player trade cancellation requests
Zap.SendClientTradeCancel.On(function(player)
	TradeService:CancelTrade(player)
end)

--- Listen for item offers
Zap.ClientSentItemTradeOffer.On(function(player: Player, data: { category: string, id: number, level: number })
	if not TradeService._CurrentlyTrading[player] then
		return
	end

	local item = TradeService:SanityCheckForItem(player, data)

	if not item then
		warn(`No item found! This player may have inputed falsified information!`)
		return
	end

	local tradeData = TradeService._CurrentlyTrading[player]
	local recipient = tradeData.Recipient

	-- Cannot change the offer if they have already accepted the offer!
	if tradeData.Accepted then
		return
	end

	-- Find if they have already inputted this item into the trade
	local ifItemExists = List.find(tradeData.Items, function(item)
		if item.category == data.category and item.id == data.id and item.level == data.level then
			return true
		end

		return false
	end)

	if ifItemExists then
		if item.Count > ifItemExists.count then
			ifItemExists.count += 1
		else
			warn(`{player.Name} tried to add more of what they don't have!`)
			return
		end
	else
		local newData = data
		newData.count = 1

		table.insert(tradeData.Items, newData)
	end

	-- Send to the recipient the offer changes
	Zap.ServerSentItemTradeOffer.Fire(recipient, tradeData.Items)
end)

--- Listen for player accepting the trade offer
Zap.ClientAcceptTradeOffer.On(function(player)
	local tradeDataHost = TradeService._CurrentlyTrading[player]

	if not tradeDataHost then
		return
	end

	tradeDataHost.Accepted = true

	local recipient = tradeDataHost.Recipient

	-- Send to the recipient that the other person has accepted the trade offer
	Zap.ServerSentAcceptTradeOffer.Fire(recipient)

	-- Check if recipient has also accepted the offer
	local tradeDataRecipient = TradeService._CurrentlyTrading[recipient]

	if not tradeDataRecipient then
		return
	end

	if tradeDataHost.Accepted and tradeDataRecipient.Accepted then
		print("Both parties accepted trade! Counting down!")
		Zap.BothPartiesAcceptedTradeOffer.FireList({ player, recipient })

		-- Countdown to the accepting, for which any players can back out now
		task.wait(3)

		-- Double check if they are still trading with each other
		if
			not player
			or not recipient
			or not TradeService._CurrentlyTrading[player]
			or not TradeService._CurrentlyTrading[recipient]
		then
			warn(`One of the parties has cancelled the trade!`)
			return
		end

		-- Ensure that the server is not currently in a datastore outage
		if (os.clock() - TradeService._LastOutageTime) < 120 then
			TradeService:CancelTrade(player)
			error("Datastore outage detected! Please try the trade again later!")
			return
		end

		-- Ensure that both recipient and host still retains the items
		local function checkItemsInQueue(target: Player, datas: { Zap.TradeData })
			for _, item in datas do
				if not TradeService:SanityCheckForItem(target, item, item.count) then
					return false
				end
			end

			return true
		end

		local hostItems = checkItemsInQueue(player, tradeDataHost.Items)
		local recipientItems = checkItemsInQueue(recipient, tradeDataRecipient.Items)

		if not hostItems or not recipientItems then
			TradeService:CancelTrade(player)
			warn(`The items were not found in one or more player's inventories!`)
			return
		end

		print("Trading!")

		local hostInventory = PlayerData:Get(player, "Inventory")
		local recipientInventory = PlayerData:Get(recipient, "Inventory")

		-- Remove both parties items first
		local function removeItems(target: Player, inventory, datas: { Zap.TradeData })
			for _, item in datas do
				local found, itemTable, level = TradeService:SanityCheckForItem(target, item)
				found.Count -= item.count

				if found.Count <= 0 then
					itemTable[level] = nil
				end
			end
		end

		removeItems(player, hostInventory, tradeDataHost.Items)
		removeItems(recipient, recipientInventory, tradeDataRecipient.Items)

		-- Add the items to both parties
		local function addItems(target: Player, inventory, datas: { Zap.TradeData })
			for _, item in datas do
				local category = item.category
				local id = tostring(item.id)
				local level = tostring(item.level)
				local count = item.count

				if not inventory[category] then
					inventory[category] = {}
				end

				if inventory[category][id] then
					if not inventory[category][id][level] then
						inventory[category][id][level] = { Count = 0 }
					end

					inventory[category][id][level].Count += count
				else
					inventory[category][id] = { [level] = table.clone(DropData) }
					inventory[category][id][level].Count = count
				end
			end
		end

		addItems(player, hostInventory, tradeDataRecipient.Items)
		addItems(recipient, recipientInventory, tradeDataHost.Items)

		print("Items traded!")

		--- Set the data and replicate these changes to the client
		PlayerData:Set(player, "Inventory", hostInventory)
		PlayerData:Set(recipient, "Inventory", recipientInventory)

		-- Accelerate profileservice saving
		local hostProfile = PlayerData:GetProfile(player)
		local recipientProfile = PlayerData:GetProfile(recipient)

		hostProfile:Save()
		recipientProfile:Save()

		print("Profiles saved from trading!")

		-- Reset trade states
		TradeService:CancelTrade(player, true)
	else
		print("Other party has not yet accepted the trade!")
	end
end)

--- Listen for client ignoring trade request toggles
Zap.ClientToggleIgnoreTradeRequest.On(function(player)
	PlayerData:Set(player, "TradeIgnoreRequests", not PlayerData:Get(player, "TradeIgnoreRequests"))
	player:SetAttribute("IgnoreTradeRequests", PlayerData:Get(player, "TradeIgnoreRequests"))
end)

--- Listen for client requesting trade option purchases
Zap.ClientPurchaseTradeFeature.SetCallback(function(player: Player)
	if PlayerData:Get(player, "Money") >= Settings.Trading_Cost then
		PlayerData:Set(player, "Money", PlayerData:Get(player, "Money") - Settings.Trading_Cost)
		PlayerData:Set(player, "TradeUnlocked", true)

		return { success = true }
	end

	return { success = false }
end)

local function Init()
	Players.PlayerRemoving:Connect(function(player: Player)
		TradeService:CancelTrade(player)
		TradeService._RecentlyInvited[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		if not player:GetAttribute("Loaded") then
			player:GetAttributeChangedSignal("Loaded"):Wait()
		end

		player:SetAttribute("IgnoreTradeRequests", PlayerData:Get(player, "TradeIgnoreRequests"))
	end)

	ProfileService.CriticalStateSignal:Connect(function()
		TradeService._LastOutageTime = os.clock()
	end)
end

Init()
return TradeService
