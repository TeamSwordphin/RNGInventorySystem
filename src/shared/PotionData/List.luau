--[[
	Both Name and Description support RichText for coloring.

	BuffsAmount should have the same values as the one in the player's Data

	Type could be "Additive" (adds onto the original values in the player's data while rolling)
	or "Override" (This will override the values in the player's data while rolling)
]]

return {
	[1] = {
		Name = "Luck Boost",
		Description = "Grants a <b>30% Luck Boost</b> for 10 seconds. Only the duration will stack if consumed again.",
		Icon = "rbxassetid://7059134236",
		Type = "Additive",
		Rarity = 2,
		Duration = 10,
		Buffs = {
			Luck = 30,
		},
	},
	[2] = {
		Name = "Roll Boost",
		Description = "Grants a <b>200% Roll Speed Boost</b> for 10 seconds. Only the duration will stack if consumed again.",
		Icon = "rbxassetid://87781150",
		Type = "Additive",
		Rarity = 3,
		Duration = 10,
		Buffs = {
			RollSpeed = 30,
		},
	},
	[3] = {
		Name = "Luck Boost Special",
		Description = "Sets your Luck stat to <b>100%</b> for 10 rolls. Only the roll count will stack if consumed again.",
		Icon = "rbxassetid://87780665",
		Type = "Override",
		Rarity = 6,
		Rolls = 10,
		Buffs = {
			RollSpeed = 30,
		},
	},
}
