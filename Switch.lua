local Switch = {}
Switch.__index = Switch

type func = (...any) -> (...any)

export type Switch = typeof(setmetatable({}, Switch)) & {
	Signal: RBXScriptSignal,
	Callback: func,
	Connection: RBXScriptConnection
}

function Switch.new(signal: RBXScriptSignal, callback: func): Switch
	local self = setmetatable({} :: Switch, Switch)
	self.Signal = signal
	self.Callback = callback
	return self
end

function Switch:Start()
	if self.Connection then
		warn("Switch is already active!")
	end
	self.Connection = self.Signal:Connect(self.Callback)
end

function Switch:Stop()
	local connection = self.Connection
	if connection then
		connection:Disconnect()
		self.Connection = nil
	end
end

return Switch