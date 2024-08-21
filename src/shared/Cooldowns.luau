--!strict

--[[

	@author Phin 2024

]]

local CooldownService = {}
local _Cooldowns: { [any]: number } = {}

function CooldownService:get(key: any): number
	local cooldown: number? = _Cooldowns[key]
	local clock: number = os.clock()

	if not cooldown or cooldown < clock then
		_Cooldowns[key] = nil
		return 0
	end

	return cooldown - clock
end

function CooldownService:set(key: any, duration: number): number
	_Cooldowns[key] = os.clock() + duration
	return _Cooldowns[key]
end

function CooldownService:destroy(key: any)
	_Cooldowns[key] = nil
end

function CooldownService:clear()
	table.clear(_Cooldowns)
end

return CooldownService
