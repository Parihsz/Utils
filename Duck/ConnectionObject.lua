local ConnectionObject = {}
ConnectionObject.__index = ConnectionObject

type callback = (Player, ...any) -> (...any)

export type ConnectionObject = typeof(setmetatable({}, ConnectionObject)) & {
	Callback: callback,
	RemoteSignal: any
}

function ConnectionObject.new(callbacks: {callback}, callback: callback): ConnectionObject
	local self = setmetatable({} :: ConnectionObject, ConnectionObject)
	self.Callbacks = callbacks
	self.Callback = callback
	return self
end

function ConnectionObject:Disconnect()
	local index = table.find(self.Callbacks, self.Callback)
	if index then
		table.remove(self.Callbacks, index)
		return
	end
	warn("Could not find callback, signal already disconnected!")
end

return ConnectionObject