--[[
	Default player data template. Adding more keys to this will automatically update existing players saves.
	Editing the values will not update automatically, you'll have to manually reconcile those changes.
]]

return {
	MaximumInventorySpace = 200,
	Inventory = {},
	PotionInventory = {},

	CraftProgress = {},
	AutoRollCraftIndex = 0,

	TradeUnlocked = false,
	TradeIgnoreRequests = false,

	Money = 500,
	RollSpeed = 2,
	Luck = 0.1,
}
