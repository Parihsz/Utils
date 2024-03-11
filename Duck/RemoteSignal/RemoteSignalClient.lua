local RemoteSignalShared = require(script.Parent:WaitForChild("RemoteSignalShared"))

local RemoteSignalClient = {}
RemoteSignalClient.__index = RemoteSignalClient

export type RemoteSignal = RemoteSignalShared.RemoteSignal & typeof(setmetatable({}, RemoteSignalClient))

local playerPacket = require(script.Parent.Parent:WaitForChild("DuckClient"):WaitForChild("PlayerPacket"))

RemoteSignalClient.Connect = RemoteSignalShared.Connect
RemoteSignalClient.Once = RemoteSignalShared.Once
RemoteSignalClient.Wait = RemoteSignalShared.Wait
RemoteSignalClient.Destroy = RemoteSignalShared.Destroy
RemoteSignalClient.DisconnectAll = RemoteSignalShared.DisconnectAll

function RemoteSignalClient.new(name: string): RemoteSignal
	local self = setmetatable({} :: RemoteSignal, RemoteSignalClient)
	self.Name = name
	self.Callbacks = {}
	return self
end

function RemoteSignalClient:Fire(...: any)
	playerPacket.Size += 1
	local size = playerPacket.Size
	playerPacket.Names[size] = self.Name
	playerPacket.Data[size] = {...}
end

return RemoteSignalClient
