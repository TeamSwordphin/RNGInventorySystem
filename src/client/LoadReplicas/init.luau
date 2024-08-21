local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicaController = require(ReplicatedStorage.Libraries.ReplicaController)
local Player = Players.LocalPlayer

local InventorySystem = require(script.Parent.Inventory)
local CraftSystem = require(script.Parent.Craft)
local TradeSystem = require(script.Parent.Trading)
local PotionInventory = require(script.Parent.PotionInventory)

--- Setup ReplicaController to listen for changes in the player's save
ReplicaController.ReplicaOfClassCreated(`{Player.UserId}_PlayerDataToken`, function(replica)
	InventorySystem:SetInventory(replica.Data.Inventory)
	InventorySystem:SetInventorySpace(replica.Data.MaximumInventorySpace)
	PotionInventory:SetInventory(replica.Data.PotionInventory)
	CraftSystem:SetCraftProgress(replica.Data.CraftProgress)
	CraftSystem:SetAutoRollIndex(replica.Data.AutoRollCraftIndex)
	TradeSystem:SetTradeEnabled(replica.Data.TradeUnlocked)

	replica:ListenToChange({ "Inventory" }, function(newInventory)
		InventorySystem:SetInventory(newInventory)
	end)

	replica:ListenToChange({ "PotionInventory" }, function(newInventory)
		PotionInventory:SetInventory(newInventory)
	end)

	replica:ListenToChange({ "MaximumInventorySpace" }, function(newValue)
		InventorySystem:SetInventorySpace(newValue)
	end)

	replica:ListenToChange({ "CraftProgress" }, function(newProgress)
		CraftSystem:SetCraftProgress(newProgress)
	end)

	replica:ListenToChange({ "AutoRollCraftIndex" }, function(newIndex)
		CraftSystem:SetAutoRollIndex(newIndex)
	end)

	replica:ListenToChange({ "TradeUnlocked" }, function(newUnlocked)
		TradeSystem:SetTradeEnabled(newUnlocked)
	end)
end)

--- This can only be ran once according to documentations
ReplicaController.RequestData()

return nil
