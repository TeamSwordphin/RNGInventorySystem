--[[

	Handles trading systems. There will be a lot of redundancies to ensure security is thorough as possible.

	@author Phin 2024

]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Settings = require(ReplicatedStorage.Modules.GlobalSettings)
local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local Dictionary = Freeze.Dictionary

local Zap = require(ServerScriptService.Network.Zap)
local PlayerData = require(ServerScriptService.ServerSystems.PlayerDataService)

local TradeService = { _RecentlyInvited = {}, _CurrentlyTrading = {} }

function TradeService:CancelTrade(player: Player)
	if TradeService._CurrentlyTrading[player] then
		-- Send cancel command
		Zap.OnServerTradeCancel.Fire(player)

		-- Cancel any recipients connected to this player
		local recipient = TradeService._CurrentlyTrading[player].Recipient
		TradeService._CurrentlyTrading[player] = nil -- Nil this first so it doesn't infinitely loop
		TradeService:CancelTrade(recipient)

		-- Put them on mild cooldown right after cancellation
		TradeService._RecentlyInvited[player] = {
			LastTradeRequestTime = os.clock() - (Settings.Trading_Cooldown * 0.6),
			InvitedFrom = player,
		}
	end
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
	}

	TradeService._CurrentlyTrading[recipient] = {
		Recipient = inviter,
		Accepted = false,
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

--- Sanity check their saves to ensure that they have this item
function TradeService:SanityCheckForItem(player, data)
	local category = data.category
	local id = data.id
	local level = data.level

	local inventory = PlayerData:Get(player, "Inventory")

	if not inventory[category] then
		warn(`No category of {category} was found in {player.Name}'s profile!`)
		return
	end

	local item = inventory[category][tostring(id)]

	if not item then
		warn(`No item id in {category} of {id} was found in {player.Name}'s profile!`)
		return
	end

	if not item[tostring(level)] then
		warn(`No item with the level {level} in {category} of {id} was found in {player.Name}'s profile!`)
		return
	end

	return item[tostring(level)]
end

--- Listen for item offers
Zap.ClientSentItemTradeOffer.On(function(player: Player, data: { category: string, id: number, level: number })
	if not TradeService._CurrentlyTrading[player] then
		return
	end

	local category = data.category
	local id = data.id
	local level = data.level
	local item = TradeService:SanityCheckForItem(player, data)

	if not item then
		warn(`No item found! This player may have inputed falsified information!`)
		return
	end

	local tradeData = TradeService._CurrentlyTrading[player]
	local recipient = tradeData.Recipient

	tradeData.Item = { category, id, level }

	-- Send to the recipient
	Zap.ServerSentItemTradeOffer.Fire(recipient, data)
end)

local function Init()
	Players.PlayerAdded:Connect(function(player: Player)
		TradeService:CancelTrade(player)
		TradeService._RecentlyInvited[player] = nil
	end)
end

Init()
return TradeService
