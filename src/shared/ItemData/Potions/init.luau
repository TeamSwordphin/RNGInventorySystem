local Category = {
	Icon = "rbxassetid://18520106884",
	Order = 3,
}

Category._Items = require(script.List)

for _, item in Category._Items do
	item.Category = script.Name
end

function Category:GetItems()
	return Category._Items
end

function Category:GetItem(item: number | string)
	return Category:GetItems()[tonumber(item)]
end

return Category
