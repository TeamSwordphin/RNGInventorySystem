--//Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--//High-level locals
local Camera = Workspace.CurrentCamera

--//Locals
local depthEffect
local dynamicConnection

--//Constants / CONFIG
local CREATE_ON_INIT = true
local IS_ENABLED = false

local PROPERTIRES = { --These are the best settings for blurring everything behind a specific object IMO
	FarIntensity = 1,
	FocusDistance = 5,
	InFocusRadius = 0, --Will dynamically change
	NearIntensity = 0,
}

--//Module begin
local DynamicDepth = {}

local function setProperties(propertyTable)
	for property, value in propertyTable do
		depthEffect[property] = value
	end
end

--//Sets the depthOfFocus effect to the distance between the camera and the part
function DynamicDepth:SetDepthToPart(targetPart, dynamicallyUpdate, timeInTween)
	if not depthEffect then
		warn("No depthEffect has been set!")
		return
	end
	--	self:Reset()

	--Get proper positioning depending on class type
	local partPosition
	if targetPart:IsA("Model") then
		if targetPart.PrimaryPart == nil then
			warn("No primary part found!")
			return
		else
			partPosition = targetPart.PrimaryPart.Position
		end
	else
		partPosition = targetPart.Position
	end

	depthEffect.Enabled = true

	--If dynamicallyUpdate, update InFocusRadius every frame, else just update initially
	if dynamicallyUpdate then
		dynamicConnection = RunService.RenderStepped:Connect(function()
			depthEffect.InFocusRadius = (Camera.CFrame.Position - partPosition).Magnitude
		end)
	else
		local inFocusRadius = (Camera.CFrame.Position - partPosition).Magnitude
		TweenService:Create(
			depthEffect,
			TweenInfo.new(timeInTween and timeInTween or 0.1, Enum.EasingStyle.Linear),
			{ InFocusRadius = inFocusRadius }
		):Play()
	end
end

--//Unbinds RunService connection
function DynamicDepth:StopUpdating(keepEffectEnabled)
	if not depthEffect then
		if dynamicConnection then
			dynamicConnection:Disconnect()
		end

		warn("No depthEffect has been set!")
	end

	if not keepEffectEnabled then
		depthEffect.Enabled = false
	end

	if dynamicConnection then
		dynamicConnection:Disconnect()
	end
end

--//Resets the DepthOfField effect to default settings or to optional args
function DynamicDepth:Reset(optionalConfig)
	self:StopUpdating()

	if optionalConfig then
		if typeof(optionalConfig) ~= "table" then
			warn("Config table is not a valid table!")
		end

		setProperties(optionalConfig)
	else
		for property, value in PROPERTIRES do
			depthEffect[property] = value
		end
	end
end

--//Mutators
function DynamicDepth:Enable()
	if not depthEffect then
		warn("No depthEffect has been set!")
		return
	end

	depthEffect.Enabled = true
end

function DynamicDepth:Disable()
	if not depthEffect then
		warn("No depthEffect has been set!")
	end

	depthEffect.Enabled = false
	self:Reset()
end

--//Brute force set's the focus radius
function DynamicDepth:SetFocusRadius(depth)
	if not depthEffect then
		warn("No depthEffect has been set!")
		return
	end

	depthEffect.InFocusRadius = depth
end

--//Overwrites the depthEffect instance with a new one
function DynamicDepth:SetEffect(effect)
	if depthEffect then
		depthEffect:Destroy()
	end

	depthEffect = effect
end

--//Initiator.  Creates instance if CREATE_ON_INIT is false
function DynamicDepth:Init()
	if CREATE_ON_INIT then
		depthEffect = Instance.new("DepthOfFieldEffect")
		depthEffect.Parent = Camera

		depthEffect.Enabled = IS_ENABLED

		--Set properties to config properties
		for property, value in PROPERTIRES do
			if depthEffect[property] == nil then
				warn("Invalid property: " .. property)
				continue
			end

			depthEffect[property] = value
		end
	end
end

DynamicDepth:Init()

return DynamicDepth
