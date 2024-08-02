local ItemData = { _Categories = {} }

function ItemData:GetCategories()
	return ItemData._Categories
end

function ItemData:GetCategory(category: string)
	return ItemData:GetCategories()[category]
end

for _, category in script:GetChildren() do
	local success, load = pcall(require, category)

	if success then
		load.Name = category.Name
		ItemData._Categories[category.Name] = load
	else
		warn(`Category Module received an error [{category.Name}]: {load}`)
	end
end

return ItemData
