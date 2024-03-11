local RunService = game:GetService("RunService")

local Clock = {}
Clock.__index = Clock

type func = (...any) -> (...any)

export type Clock = typeof(setmetatable({}, Clock)) & {
	_interval: number,
	_callback: func,
	_thread: thread
}

local function callbackLoop(self: Clock)
	local callback = self._callback
	return coroutine.create(function()
		while true do
			callback()
			task.wait(self._interval)
		end
	end)
end

function Clock.new(interval: number, callback: func): Clock
	local self = setmetatable({} :: Clock, Clock)
	self._interval = interval
	self._callback = callback
	self._thread = callbackLoop(self)
	return self
end

function Clock:Start()
	local status = coroutine.status(self._thread)
	if status == "dead" then
		self._thread = callbackLoop(self)
	end
	coroutine.resume(self._thread)
end

function Clock:Stop()
	coroutine.close(self._thread)
end

return Clock