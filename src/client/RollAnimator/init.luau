local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RarityReference = require(ReplicatedStorage.Modules.RarityReference)
local ParticleEmitter = require(ReplicatedStorage.Modules.ParticleEmitter)
local Janitor = require(ReplicatedStorage.Libraries.Janitor)
local Spring = require(ReplicatedStorage.Libraries.Spring)

local Interface = Players.LocalPlayer.PlayerGui:WaitForChild("RollAnimation")
local IsRolling = false

local Cleaner = Janitor.new()
local Shaker = Spring.new(Vector3.zero)
Shaker.Speed = 50
Shaker.Damper = 0.1

local RollAnimator = {}

local SEED = Random.new()
local DEFAULT_SCALE = 1
local EPIC_ANIMATION_REQUIREMENT = 20 -- If "1 in EPIC_ANIMATION_REQUIREMENT" appears, the epic anim ver will be played instead

function RollAnimator:IsRolling()
	return IsRolling
end

--- Cancel the rolling animation
function RollAnimator:Cancel()
	Cleaner:Cleanup()
	Interface.Enabled = false
	IsRolling = false
end

function CommaSeparateNumber(num)
	local _, _, minus, int, fraction = string.find(tostring(num or 0), "([-]?)(%d+)([.]?%d*)")
	int = string.gsub(string.reverse(int), "(%d%d%d)", "%1,")
	return minus .. string.gsub(string.reverse(int), "^,", "") .. fraction
end

--- Start the rolling animation, provided it has not yet started
function RollAnimator:Activate(information: any, durationScale: number?)
	if not information then
		error("Please add an information table!")
	end

	if IsRolling then
		return
	else
		IsRolling = true
	end

	for _, ui in CollectionService:GetTagged("_UIRollAnimators") do
		ui.Visible = false
	end

	Cleaner:Add(task.defer(function()
		-- Set initial variables
		local scale: number = durationScale or DEFAULT_SCALE
		local shakeJanitor = Cleaner:Add(Janitor.new(), "Destroy")
		local rarity = RarityReference[information.Rarity]

		-- Set initial states
		local background = Interface.Background
		local assets = Interface.AssetRoll
		local square = assets.Square
		local smokeContainer = square.SmokeContainer
		local cutter = square.Cutter
		local reward = assets.Reward
		local chance = math.floor(100 / (information.DropChance or 100))

		for _, ui in CollectionService:GetTagged("_UIRibbon") do
			ui.ImageTransparency = 1

			if not ui:GetAttribute("Position") then
				ui:SetAttribute("Position", ui.Position)
			else
				ui.Position = ui:GetAttribute("Position")
			end
		end

		assets.Visible = true
		assets.Size = UDim2.fromScale(1, 1)
		reward.Rarity.TextColor3 = rarity.Color
		reward.Rarity.Text = `1 in {CommaSeparateNumber(chance)}`
		reward.Rarity.TextTransparency = 0
		reward.Rarity.Size = UDim2.fromScale(0, 0)
		reward.Shine.ImageColor3 = rarity.Color
		reward.Shine.ImageTransparency = 1
		reward.Shine.Rotation = 0
		reward.Size = UDim2.fromScale(0.45, 0.45)
		reward.Glow.UIGradient.Color = ColorSequence.new(rarity.Color)
		reward.Glow.BackgroundTransparency = 0
		reward.Icon.Image = information.Icon
		reward.Icon.ImageTransparency = 0
		reward.Visible = false
		background.BackgroundTransparency = 1
		cutter.BackgroundTransparency = 1
		cutter.UIGradient.Offset = Vector2.new(0, -1)
		square.Size = UDim2.fromScale(0.35, 0.35)
		square.BackgroundTransparency = 1
		square.Position = UDim2.fromScale(0.5, 0.75)
		square.Rotation = 10
		square.Ribbon.UIGradient.Enabled = false
		square.RibbonCut.Visible = false
		square.RibbonCut.ImageTransparency = 0
		square.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		Interface.Enabled = true

		-- Start animations
		local bgTween = Cleaner:Add(
			TweenService:Create(background, TweenInfo.new(0.2 / scale), { BackgroundTransparency = 0.15 }),
			"Cancel"
		)
		bgTween:Play()
		bgTween.Completed:Wait()

		-- Tween the ribbon transparencies
		for _, ui in CollectionService:GetTagged("_UIRibbon") do
			if ui:HasTag("_UIRibbonCut") then
				continue
			end

			local ribbon = Cleaner:Add(TweenService:Create(ui, TweenInfo.new(0.5), { ImageTransparency = 0 }), "Cancel")
			ribbon:Play()
		end

		-- Tween the cube up
		local cube1 = Cleaner:Add(
			TweenService:Create(
				square,
				TweenInfo.new(0.3 / scale),
				{ BackgroundTransparency = 0, Rotation = -5, Position = UDim2.fromScale(0.5, 0.45) }
			),
			"Cancel"
		)
		cube1:Play()
		cube1.Completed:Wait()

		-- Cube falls back down
		local bounceDuration = 0.2 / scale
		local cubeFaller = Cleaner:Add(
			TweenService:Create(
				square,
				TweenInfo.new(bounceDuration, Enum.EasingStyle.Bounce),
				{ Rotation = 0, Position = UDim2.fromScale(0.5, 0.5) }
			),
			"Cancel"
		)
		cubeFaller:Play()

		-- Play smoke particle effects upon landing
		Cleaner:Add(task.delay(bounceDuration * 0.4, function() -- https://easings.net/#easeOutBounce for the timings
			local explodeClone = Cleaner:Add(Interface.Templates.Smoke:Clone(), "Destroy")
			explodeClone.Position = UDim2.fromScale(0.5, 1)
			explodeClone.Visible = true

			local emitter = Cleaner:Add(ParticleEmitter.new(assets, explodeClone), "Destroy")
			emitter.rate = 0

			local posX = smokeContainer.AbsolutePosition.X
			local posY = smokeContainer.AbsolutePosition.Y
			local sizeX = smokeContainer.AbsoluteSize.X
			local sizeY = smokeContainer.AbsoluteSize.Y

			emitter.onSpawn = function(particle)
				particle.position = Vector2.new(SEED:NextNumber(posX, posX + sizeX), posY + sizeY)
				particle.velocity = Vector2.new(SEED:NextNumber(-400, 400), SEED:NextNumber(-200, 900))
				particle.maxAge = 10 / scale

				local size = SEED:NextNumber(0.06, 0.08)
				particle.element.Size = UDim2.fromScale(size, size)
				particle.element.Rotation = SEED:NextNumber(0, 180)
			end

			emitter.onUpdate = function(particle, deltaTime)
				particle.velocity = particle.velocity - Vector2.new(0, 10)
				particle.position = particle.position - (particle.velocity / 3 * deltaTime)
				particle.element.ImageTransparency += 0.2 * deltaTime
			end

			emitter:Emit(SEED:NextInteger(40, 80))
		end))

		cubeFaller.Completed:Wait()

		-- Arbitrary wait
		task.wait(0.1 / scale)

		-- Cut the ribbon!
		local cutDuration: number = 0.3 / scale
		local cutAppear: number = cutDuration * 0.5

		shakeJanitor:Add(RunService.PostSimulation:Connect(function()
			square.Position = UDim2.new(0.5, 0 + Shaker.Position.X * 0.5, 0.5, 0 + Shaker.Position.Z * 0.5)
		end))

		local cut = Cleaner:Add(TweenService:Create(cutter, TweenInfo.new(cutAppear), { BackgroundTransparency = 0 }))
		cut:Play()

		local cutOffset = Cleaner:Add(
			TweenService:Create(cutter.UIGradient, TweenInfo.new(cutDuration), { Offset = Vector2.new(0, 1) })
		)
		cutOffset:Play()

		-- Add cutting effects
		Cleaner:Add(task.delay(cutDuration * 0.4, function()
			local maxBump = 1000
			local zBump = SEED:NextNumber(-maxBump * 4, -maxBump)
			Shaker:Impulse(Vector3.new(SEED:NextNumber(-maxBump, maxBump), 0, zBump))

			square.Ribbon.UIGradient.Enabled = true
			square.RibbonCut.Visible = true

			local ribbonRightLower = Cleaner:Add(
				TweenService:Create(
					square.RibbonRightSide,
					TweenInfo.new(0.05 / scale),
					{ Position = UDim2.fromScale(1, 0.525) }
				),
				"Cancel"
			)
			ribbonRightLower:Play()

			-- Play ribbon bit particles
			local particle = Cleaner:Add(Interface.Templates.RibbonBits:Clone(), "Destroy")
			particle.Position = UDim2.fromScale(0.5, 1)
			particle.Visible = true

			local emitter = Cleaner:Add(ParticleEmitter.new(assets, particle), "Destroy")
			emitter.rate = 0

			local posX = square.Ribbon.AbsolutePosition.X
			local posY = square.Ribbon.AbsolutePosition.Y
			local sizeX = square.Ribbon.AbsoluteSize.X
			local sizeY = square.Ribbon.AbsoluteSize.Y

			emitter.onSpawn = function(particle)
				particle.position = Vector2.new(posX + (sizeX * 0.5), posY + (sizeY * 0.5))
				particle.velocity = Vector2.new(SEED:NextNumber(1000, 2000), SEED:NextNumber(-5000, -2000))
				particle.maxAge = 10 / scale
			end

			emitter.onUpdate = function(particle, deltaTime)
				particle.velocity = particle.velocity - Vector2.new(0, 10)
				particle.position = particle.position - (particle.velocity / 3 * deltaTime)
				particle.element.BackgroundTransparency += 3 * deltaTime
			end

			emitter:Emit(SEED:NextInteger(5, 6))
		end))

		cutOffset.Completed:Wait()

		-- Arbitrary wait
		task.wait(0.4 / scale)

		shakeJanitor:Cleanup()

		-- Tween the ribbons and invisible them
		for _, ui in CollectionService:GetTagged("_UIRibbon") do
			local ribbon = Cleaner:Add(
				TweenService:Create(
					ui,
					TweenInfo.new(0.6 / scale),
					{ ImageTransparency = 1, Position = ui.Position + UDim2.fromScale(0, 1) }
				),
				"Cancel"
			)
			ribbon:Play()
		end

		-- Arbitrary wait
		task.wait(0.1 / scale)

		-- Enlarge the cube to have the illusion of closeness
		local cubeEnlarge = Cleaner:Add(
			TweenService:Create(square, TweenInfo.new(0.4 / scale), { Size = UDim2.fromScale(0.45, 0.45) }),
			"Cancel"
		)
		cubeEnlarge:Play()
		cubeEnlarge.Completed:Wait()

		-- Transform cube into an item!
		reward.Visible = true

		local epic = chance >= EPIC_ANIMATION_REQUIREMENT
		local unboxDuration = (epic and 3 or 0.5) / scale

		-- Play epic firework animation if chance is within margins
		if epic then
			-- Make the cube a lil lighter
			local cubeColor = Cleaner:Add(
				TweenService:Create(
					square,
					TweenInfo.new(unboxDuration),
					{ BackgroundColor3 = Color3.fromRGB(20, 20, 20) }
				),
				"Cancel"
			)
			cubeColor:Play()

			local shakeScale = 0
			local shakeGoal = 0.8
			local canContinue = false

			shakeJanitor:Add(RunService.PostSimulation:Connect(function(dt)
				assets.Position = UDim2.new(0.5, 0 + Shaker.Position.X * 0.5, 0.5, 0 + Shaker.Position.Z * 0.5)

				if shakeScale > 0 then
					assets.Size = UDim2.fromScale(1 + (shakeScale * 0.15), 1 + (shakeScale * 0.15))
				end

				if canContinue or shakeScale >= shakeGoal then
					return
				end

				local maxBump = 1000 * shakeScale
				local zBump = SEED:NextNumber(-maxBump * 4, -maxBump)
				Shaker:Impulse(Vector3.new(SEED:NextNumber(-maxBump, maxBump), 0, zBump))

				shakeScale += ((shakeGoal / unboxDuration) * scale) * dt
			end))

			task.delay((3 + unboxDuration) / scale, shakeJanitor.Cleanup, shakeJanitor)

			-- Play fireworks?
			task.delay(unboxDuration / scale, function()
				local function fireFirework()
					-- Spawn the missile from the bottom of the screen
					local particle = Cleaner:Add(Interface.Templates.RibbonBits:Clone(), "Destroy")
					particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					particle.Position = UDim2.fromScale(0.5, 1)
					particle.Visible = true

					local emitter = Cleaner:Add(ParticleEmitter.new(assets, particle), "Destroy")
					emitter.rate = 0

					local posX = assets.AbsolutePosition.X
					local posY = assets.AbsolutePosition.Y
					local sizeX = assets.AbsoluteSize.X
					local sizeY = assets.AbsoluteSize.Y

					local goalDt = 0
					local goal = SEED:NextNumber(0.25, 1.5)

					local trailDt = 0
					local explodePos

					emitter.onSpawn = function(particle)
						particle.position = Vector2.new(SEED:NextNumber(posX, posX + sizeX), posY + sizeY)
						particle.velocity = Vector2.new(0, SEED:NextNumber(2000, 3000))
						particle.maxAge = 5 / scale
					end

					emitter.onUpdate = function(particle, deltaTime)
						particle.velocity = particle.velocity - Vector2.new(0, 10)
						particle.position = particle.position - (particle.velocity / 3 * deltaTime)

						trailDt += deltaTime
						goalDt += deltaTime

						-- Explode!!
						if goalDt >= goal then
							if not explodePos then
								explodePos = particle.position
								particle.element.BackgroundTransparency = 1

								local particleItem = Cleaner:Add(Interface.Templates.RibbonBits:Clone(), "Destroy")
								particleItem.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
								particleItem.Position = UDim2.fromScale(0.5, 1)
								particleItem.Size = UDim2.fromOffset(5, 5)
								particleItem.Visible = true

								local emitterTrail = Cleaner:Add(ParticleEmitter.new(assets, particleItem), "Destroy")
								emitterTrail.rate = 0

								local tickGoal = 5

								emitterTrail.onSpawn = function(particleTrail)
									particleTrail.position = explodePos
									particleTrail.velocity =
										Vector2.new(SEED:NextNumber(-2000, 2000), SEED:NextNumber(-2000, 2000))
									particleTrail.maxAge = 5 / scale
									particleTrail.element.Rotation = SEED:NextNumber(-180, 180)
								end

								emitterTrail.onUpdate = function(particleTrail, deltaTrail)
									particleTrail.velocity = particleTrail.velocity - Vector2.new(0, 3)
									particleTrail.position = particleTrail.position
										- (particleTrail.velocity / 3 * deltaTime)

									local hue = os.clock() % tickGoal / tickGoal
									particleTrail.element.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
									particleTrail.element.BackgroundTransparency += 1 * deltaTime
								end

								emitterTrail:Emit(SEED:NextInteger(40, 60))
							end
						else
							-- Create trail particle
							if trailDt >= 0.06 then
								trailDt = 0

								local particleItem = Cleaner:Add(Interface.Templates.RibbonBits:Clone(), "Destroy")
								particleItem.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
								particleItem.Position = UDim2.fromScale(0.5, 1)
								particleItem.Size = UDim2.fromOffset(2, 2)
								particleItem.Visible = true

								local emitterTrail = Cleaner:Add(ParticleEmitter.new(assets, particleItem), "Destroy")
								emitterTrail.rate = 0

								local offset = SEED:NextNumber(-10, 10)

								emitterTrail.onSpawn = function(particleTrail)
									particleTrail.position = particle.position
									particleTrail.maxAge = 5 / scale
								end

								emitterTrail.onUpdate = function(particleTrail)
									particleTrail.velocity = particleTrail.velocity - Vector2.new(offset, 10)
									particleTrail.position = particleTrail.position
										- (particleTrail.velocity / 3 * deltaTime)
									particleTrail.element.BackgroundTransparency += 2 * deltaTime
								end

								emitterTrail:Emit(SEED:NextInteger(2, 3))
							end
						end
					end

					emitter:Emit(1)
				end

				-- Ensure that teh shake ends gracefully
				canContinue = true
				shakeScale = 0

				local assetResize = Cleaner:Add(
					TweenService:Create(assets, TweenInfo.new(0.5 / scale), { Size = UDim2.fromScale(1, 1) }),
					"Cancel"
				)
				assetResize:Play()

				for i = 1, 12 do
					fireFirework()
					task.wait(SEED:NextNumber(shakeGoal * 0.15, shakeGoal * 0.2) / scale)
				end
			end)
		end

		local cubeMove = Cleaner:Add(
			TweenService:Create(square, TweenInfo.new(unboxDuration), { Position = UDim2.fromScale(0.5, 0.4) }),
			"Cancel"
		)
		cubeMove:Play()
		cubeMove.Completed:Wait()

		-- Move cube out of the way!
		local cubeMove2 = Cleaner:Add(
			TweenService:Create(square, TweenInfo.new(1 / scale), { Position = UDim2.fromScale(0.5, -1.5) }),
			"Cancel"
		)
		cubeMove2:Play()

		-- Reveal rewards
		local glowRemove = Cleaner:Add(
			TweenService:Create(reward.Glow, TweenInfo.new(0.1 / scale), { BackgroundTransparency = 1 }),
			"Cancel"
		)
		glowRemove:Play()
		glowRemove.Completed:Wait()

		local rewardSize = Cleaner:Add(
			TweenService:Create(reward, TweenInfo.new(0.2 / scale), { Size = UDim2.fromScale(0.6, 0.6) }),
			"Cancel"
		)
		rewardSize:Play()

		local rewardShine = Cleaner:Add(
			TweenService:Create(reward.Shine, TweenInfo.new(0.1 / scale), { ImageTransparency = 0.85 }),
			"Cancel"
		)
		rewardShine:Play()

		local rotateShine = Cleaner:Add(
			TweenService:Create(reward.Shine, TweenInfo.new(10, Enum.EasingStyle.Linear), { Rotation = 180 }),
			"Cancel"
		)
		rotateShine:Play()

		local rewardRaritySize = Cleaner:Add(
			TweenService:Create(
				reward.Rarity,
				TweenInfo.new(0.1 / scale, Enum.EasingStyle.Back),
				{ Size = UDim2.fromScale(1, 0.2) }
			),
			"Cancel"
		)
		rewardRaritySize:Play()

		task.wait((epic and 5 or 1.5) / scale)

		-- Finish up the animations
		local bgTween2 = Cleaner:Add(
			TweenService:Create(background, TweenInfo.new(0.2 / scale), { BackgroundTransparency = 1 }),
			"Cancel"
		)
		bgTween2:Play()

		local rewardShine2 = Cleaner:Add(
			TweenService:Create(reward.Shine, TweenInfo.new(0.2 / scale), { ImageTransparency = 1 }),
			"Cancel"
		)
		rewardShine2:Play()

		local rewardIcon = Cleaner:Add(
			TweenService:Create(reward.Icon, TweenInfo.new(0.2 / scale), { ImageTransparency = 1 }),
			"Cancel"
		)
		rewardIcon:Play()

		local rewardRarity = Cleaner:Add(
			TweenService:Create(
				reward.Rarity,
				TweenInfo.new(0.2 / scale, Enum.EasingStyle.Back),
				{ TextTransparency = 1 }
			),
			"Cancel"
		)

		rewardRarity:Play()
		bgTween2.Completed:Wait()
		RollAnimator:Cancel()
	end))
end

--- Start the merge animation
function RollAnimator:ActivateMerge(information: any, previousLevel: number, newLevel: number, durationScale: number?)
	if not information then
		error("Please add an information table!")
	end

	if IsRolling then
		return
	else
		IsRolling = true
	end

	for _, ui in CollectionService:GetTagged("_UIRollAnimators") do
		ui.Visible = false
	end

	Cleaner:Add(task.defer(function()
		-- Set initial variables
		local scale: number = durationScale or DEFAULT_SCALE
		local rarity = RarityReference[information.Rarity]

		-- Set initial states
		local background = Interface.Background
		local assets = Interface.AssetMerge
		local shineContainer = assets.ShineBoundary
		local shine = shineContainer.Shine
		local card = assets.Card
		local title = card.Title
		local rewardShine = card.Reward.Shiny
		local icon = card.Reward.Icon
		local iconFader = card.Reward.IconFader
		local stat = card.Stats
		local rarityLabel = card.Rarity
		local ok = assets.Ok
		local chance = math.floor(100 / (information.DropChance or 100))

		for _, ui in CollectionService:GetTagged("_UIAssetMergeStats") do
			if ui:IsA("ImageLabel") then
				ui.ImageTransparency = 1
			elseif ui:IsA("TextLabel") then
				ui.TextTransparency = 1
			end
		end

		stat.OldAmount.Text = CommaSeparateNumber(information.Levels[previousLevel].Money)
		stat.NewAmount.Text = CommaSeparateNumber(information.Levels[newLevel].Money)
		stat.Size = UDim2.fromScale(0.6, 0)
		assets.Visible = true
		assets.Size = UDim2.fromScale(0, 0)
		card.BackgroundTransparency = 0.75
		shineContainer.GroupTransparency = 1
		shine.Position = UDim2.fromScale(-0.4, 0.5)
		title.TextTransparency = 1
		title.Size = UDim2.fromScale(1, 0)
		title.Text = `Building Merged - Lv.{newLevel}`
		rewardShine.GroupTransparency = 0.6
		icon.Size = UDim2.fromScale(0.7, 0.7)
		iconFader.ImageTransparency = 0.5
		iconFader.Size = icon.Size
		iconFader.Visible = false
		icon.Image = information.Icon or ""
		iconFader.Image = icon.Image
		rarityLabel.Size = UDim2.fromScale(0.8, 0)
		rarityLabel.TextTransparency = 1
		rarityLabel.Text = `1 in {CommaSeparateNumber(chance)}`
		rarityLabel.TextColor3 = rarity.Color
		ok.Position = UDim2.fromScale(0.5, 1.2)
		ok.Visible = false
		Interface.Enabled = true

		-- Start animations
		local bgTween = Cleaner:Add(
			TweenService:Create(background, TweenInfo.new(0.2 / scale), { BackgroundTransparency = 0.15 }),
			"Cancel"
		)
		bgTween:Play()
		bgTween.Completed:Wait()

		-- Make the card bigger!
		local sizeDuration = 0.3

		local assetBig = Cleaner:Add(
			TweenService:Create(assets, TweenInfo.new(sizeDuration / scale), { Size = UDim2.fromScale(1, 1) }),
			"Cancel"
		)
		assetBig:Play()

		task.wait((sizeDuration * 0.8) / scale)

		local rewardShine1 = Cleaner:Add(
			TweenService:Create(rewardShine, TweenInfo.new(0.6 / scale), { GroupTransparency = 1 }),
			"Cancel"
		)
		rewardShine1:Play()

		task.wait(0.2 / scale)

		local titleSize = Cleaner:Add(
			TweenService:Create(title, TweenInfo.new(0.4 / scale), { Size = UDim2.fromScale(1, 0.2) }),
			"Cancel"
		)
		titleSize:Play()
		titleSize.Completed:Wait()

		local titleView =
			Cleaner:Add(TweenService:Create(title, TweenInfo.new(0.3 / scale), { TextTransparency = 0 }), "Cancel")
		titleView:Play()

		-- Pop the icon!
		iconFader.Visible = true

		local iconFadePop = Cleaner:Add(
			TweenService:Create(
				iconFader,
				TweenInfo.new(0.6 / scale),
				{ Size = UDim2.fromScale(1.25, 1.25), ImageTransparency = 1 }
			),
			"Cancel"
		)
		iconFadePop:Play()

		local rewardShine2 = Cleaner:Add(
			TweenService:Create(rewardShine, TweenInfo.new(0.2 / scale), { GroupTransparency = 0.8 }),
			"Cancel"
		)
		rewardShine2:Play()
		rewardShine2.Completed:Wait()

		local rewardShine3 = Cleaner:Add(
			TweenService:Create(
				rewardShine,
				TweenInfo.new(1 / scale, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
				{ GroupTransparency = 0.7 }
			),
			"Cancel"
		)
		rewardShine3:Play()

		-- Do the diagonal shine thingie
		local shineMoveDuration = 2

		Cleaner:Add(task.delay(shineMoveDuration * 0.1, function()
			local diagonalShineTransparency1 = Cleaner:Add(
				TweenService:Create(shineContainer, TweenInfo.new(0.6 / scale), { GroupTransparency = 0.98 }),
				"Cancel"
			)
			diagonalShineTransparency1:Play()
		end))

		local diagonalShineMove = Cleaner:Add(
			TweenService:Create(shine, TweenInfo.new(shineMoveDuration / scale), { Position = UDim2.fromScale(1, 0.5) }),
			"Cancel"
		)
		diagonalShineMove:Play()

		task.wait((shineMoveDuration * 0.3) / scale)

		task.delay((shineMoveDuration * 0.4) / scale, function()
			local diagonalShineTransparency2 = Cleaner:Add(
				TweenService:Create(
					shineContainer,
					TweenInfo.new((shineMoveDuration * 0.2) / scale),
					{ GroupTransparency = 1 }
				),
				"Cancel"
			)
			diagonalShineTransparency2:Play()
		end)

		-- Reveal stats
		local statResize = Cleaner:Add(
			TweenService:Create(stat, TweenInfo.new(0.3 / scale), { Size = UDim2.fromScale(0.6, 0.1) }),
			"Cancel"
		)
		statResize:Play()

		local amount = 0

		for _, ui in CollectionService:GetTagged("_UIAssetMergeStats") do
			local order = ui.LayoutOrder
			amount += 1

			task.delay((order * 0.2) / scale, function()
				if ui:IsA("ImageLabel") then
					local reveal = Cleaner:Add(
						TweenService:Create(ui, TweenInfo.new(0.2 / scale), { ImageTransparency = 0 }),
						"Cancel"
					)
					reveal:Play()
				elseif ui:IsA("TextLabel") then
					local reveal = Cleaner:Add(
						TweenService:Create(ui, TweenInfo.new(0.2 / scale), { TextTransparency = 0 }),
						"Cancel"
					)
					reveal:Play()
				end
			end)
		end

		-- Reveal rarity
		task.wait((amount * 0.1) / scale)

		local raritySize = Cleaner:Add(
			TweenService:Create(rarityLabel, TweenInfo.new(0.2 / scale), { Size = UDim2.fromScale(0.8, 0.15) }),
			"Cancel"
		)
		raritySize:Play()
		raritySize.Completed:Wait()

		local rarityTransparency = Cleaner:Add(
			TweenService:Create(rarityLabel, TweenInfo.new(0.2 / scale), { TextTransparency = 0 }),
			"Cancel"
		)
		rarityTransparency:Play()
		rarityTransparency.Completed:Wait()

		ok.Visible = true

		local okButton = Cleaner:Add(
			TweenService:Create(ok, TweenInfo.new(0.5 / scale), { Position = UDim2.fromScale(0.5, 0.97) }),
			"Cancel"
		)
		okButton:Play()
	end))
end

Interface.AssetMerge.Ok.MouseButton1Click:Connect(function()
	Interface.AssetMerge.Visible = false

	local background = Interface.Background
	local bgTween2 =
		Cleaner:Add(TweenService:Create(background, TweenInfo.new(0.2), { BackgroundTransparency = 1 }), "Cancel")
	bgTween2:Play()
	bgTween2.Completed:Wait()

	RollAnimator:Cancel()
end)

--- DEBUG! Remove afterwards.
task.defer(function()
	Players.LocalPlayer.PlayerGui.Inventory.Info.Frame.UpgradeFrame.UpgradeButton.MouseButton1Click:Connect(function()
		local itemData = require(ReplicatedStorage.Modules.ItemData)
		local all = itemData:GetCategory("All")
		local item = all:GetItem(5)

		RollAnimator:ActivateMerge(item, 1, 3)
	end)
end)

Interface.Enabled = false
return RollAnimator
