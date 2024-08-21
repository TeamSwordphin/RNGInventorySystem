local PotionList = {}
local List = require(script.List)

for key, potion in List do
	potion._Key = key
end

function PotionList:GetPotionList()
	return List
end

return PotionList
