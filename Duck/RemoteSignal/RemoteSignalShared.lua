local ConnectionObject = require(script.Parent.Parent:WaitForChild("ConnectionObject"))

local RemoteSignalShared = {}

type ConnectionObject = ConnectionObject.ConnectionObject

export type callback = (Player, ...any) -> (...any)

export type RemoteSignal = {
	Name: string,
	Callbacks: {callback}
}

local remoteSignals = require(script.Parent.Parent:WaitForChild("RemoteSignals"))

function RemoteSignalShared:Connect(callback: callback): ConnectionObject
	table.insert(self.Callbacks, callback)
	return ConnectionObject.new(self.Callbacks, callback)
end

function RemoteSignalShared:Wait(): any
	local thread = coroutine.running()
	local returnValue
	self:Once(function(...)
		returnValue = {...}
		coroutine.resume(thread)
	end)
	coroutine.yield()
	return table.unpack(returnValue)
end

function RemoteSignalShared:Once(callback: callback)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
end

function RemoteSignalShared:Destroy()
	remoteSignals[self.Name] = nil
end

function RemoteSignalShared:DisconnectAll()
	table.clear(self.Callbacks)
end

return RemoteSignalShared