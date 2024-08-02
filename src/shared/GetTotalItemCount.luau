local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Freeze = require(ReplicatedStorage.Libraries.Freeze)
local Dictionary = Freeze.Dictionary

return function(inventory)
	local totalCount = 0

	Dictionary.forEach(inventory, function(data)
		for level, inner in data do
			totalCount += inner.Count
		end

		return true
	end)

	return totalCount
end
