local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PotionSpawnerVisualizer = {}

local function GeneratePotionVisual(part: BasePart)
	local potion = ReplicatedStorage.Assets[part:GetAttribute("Type")]:Clone()
	potion:PivotTo(part.CFrame)
	potion.Parent = part

	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = potion.PrimaryPart
	weldConstraint.Part1 = part
	weldConstraint.Parent = potion.PrimaryPart
end

local function Init()
	for _, potion in CollectionService:GetTagged("_Potion") do
		GeneratePotionVisual(potion)
	end

	CollectionService:GetInstanceAddedSignal("_Potion"):Connect(GeneratePotionVisual)
end

Init()
return PotionSpawnerVisualizer
