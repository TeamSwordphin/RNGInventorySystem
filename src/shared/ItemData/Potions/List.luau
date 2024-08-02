--[[

	The index number (usually in the form of square brackets [number]) is important! This references the index if this item in the player's
	save. If you change this index number, the item in ALL player saves will also be changed, and so will the global analytics! Each item
	should have unique index numbers.

	For rarity, please refer to Modules/RarityReference on which number to use.

	Drop chance is using Weighted Totals for randomization rather than flat percentages. See Libraries/RandomSelection for API information.

]]

return {
	[1] = {
		Name = "Potion Example 1",
		Description = "An example item.",
		Icon = "rbxassetid://14579141398",
		Rarity = 6,
		DropChance = 20,
		Speed = 6,
		Levels = {
			[1] = {
				Money = 20,
			},
			[2] = {
				Money = 40,
			},
			[3] = {
				Money = 60,
			},
			[4] = {
				Money = 80,
			},
			[5] = {
				Money = 100,
			},
		},
	},
	[2] = {
		Name = "Potion Example 2",
		Description = "An example item.",
		Icon = "rbxassetid://14579141398",
		Rarity = 1,
		DropChance = 100,
		Speed = 6,
		Levels = {
			[1] = {
				Money = 20,
			},
			[2] = {
				Money = 40,
			},
			[3] = {
				Money = 60,
			},
			[4] = {
				Money = 80,
			},
			[5] = {
				Money = 100,
			},
		},
	},
}
