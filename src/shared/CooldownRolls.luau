--!strict

--[[

	@author Phin 2024

]]

local CooldownService = {}
local _Cooldowns: { [any]: number } = {}

function CooldownService:get(key: any): number
	local cooldown: number? = _Cooldowns[key]
	return cooldown or 0
end

function CooldownService:set(key: any, rolls: number): number
	_Cooldowns[key] = (_Cooldowns[key] or 0) + rolls
	return _Cooldowns[key]
end

function CooldownService:destroy(key: any)
	_Cooldowns[key] = nil
end

function CooldownService:clear()
	table.clear(_Cooldowns)
end

return CooldownService
