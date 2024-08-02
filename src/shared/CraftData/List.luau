--[[
	Both Name and Description support RichText for coloring.

	Rewards should be keys found in PlayerData's profile.Data
]]

return {
	{
		Name = "Buff Example",
		Description = "Pretty cool buff right here.\n\n<font color='#ffea72'>+500 Money</font>, <font color='#75ff6b'>+2 Luck</font>, <font color='#7398ff'>+5 Roll Speed</font>",
		Recipe = {
			{ Category = "All", Id = 2, Count = 2, Level = 1 },
			{ Category = "All", Id = 1, Count = 2, Level = 1 },
			{ Category = "All", Id = 3, Count = 1, Level = 1 },
			{ Category = "All", Id = 3, Count = 2, Level = 3 },
		},
		Rewards = {
			Money = 500,
			Luck = 2,
			RollSpeed = 5,
		},
	},
	{
		Name = "Buff Example 2",
		Description = "Mega Luck!\n\n<font color='#75ff6b'>+20 Luck</font>",
		Recipe = {
			{ Category = "All", Id = 4, Count = 1, Level = 1 },
			{ Category = "All", Id = 3, Count = 2, Level = 1 },
		},
		Rewards = {
			Luck = 20,
		},
	},
	{
		Name = "Buff Example 3",
		Description = "Here, have some change.\n\n<font color='#ffea72'>+5000000 Money</font>",
		Recipe = {
			{ Category = "All", Id = 3, Count = 5, Level = 1 },
			{ Category = "All", Id = 2, Count = 10, Level = 1 },
			{ Category = "All", Id = 1, Count = 20, Level = 1 },
			{ Category = "All", Id = 4, Count = 2, Level = 1 },
			{ Category = "All", Id = 5, Count = 1, Level = 1 },
		},
		Rewards = { Money = 5000000 },
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
	{
		Name = "Dummy Buff",
		Description = "Nothing of note here.",
		Recipe = {
			{ Category = "All", Id = 6, Count = 999, Level = 1 },
		},
		Rewards = {},
	},
}
