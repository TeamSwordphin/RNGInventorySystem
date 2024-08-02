--[[
	Default player data template. Adding more keys to this will automatically update existing players saves.
	Editing the values will not update automatically, you'll have to manually reconcile those changes.
]]

return {
	MaximumInventorySpace = 200,
	Inventory = {},

	CraftProgress = {},
	AutoRollCraftIndex = 0,

	TradeUnlocked = true,
	TradeIgnoreRequests = false,

	Money = 0,
	RollSpeed = 2,
	Luck = 0,
}
