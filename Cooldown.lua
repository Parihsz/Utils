local Cooldown = {}
Cooldown.__index = Cooldown

type func = (...any) -> (...any)

export type Cooldown = typeof(setmetatable({}, Cooldown)) & {
	Cooldown: number,
	Callback: func,
	_lastTriggered: number
}

local function isOffCooldown(cooldown: number, lastTriggered: number, currentTime: number): boolean
	if currentTime - lastTriggered >= cooldown then
		return true
	end
	return false
end

function Cooldown.new(cooldown: number, callback: func): Cooldown
	local self = setmetatable({} :: Cooldown, Cooldown)
	self.Cooldown = cooldown
	self.Callback = callback
	self._lastTriggered = 0
	return self
end

function Cooldown:Trigger()
	if isOffCooldown(self.Cooldown, self._lastTriggered, os.clock()) then
		self._lastTriggered = os.clock()
		self.Callback()
	end
end

return Cooldown