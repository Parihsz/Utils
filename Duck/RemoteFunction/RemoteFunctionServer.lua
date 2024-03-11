local Players = game:GetService("Players")

local Promise = require(script.Parent.Parent.Parent.Promise)
local RemoteSignal = require(script.Parent.Parent.RemoteSignal.RemoteSignalServer)

local RemoteFunctionServer = {}
RemoteFunctionServer.__index = RemoteFunctionServer

type Promise = Promise.Promise
type RemoteSignal = RemoteSignal.RemoteSignal

type func = (...any) -> (...any)

export type RemoteFunction = typeof(setmetatable({}, RemoteFunctionServer)) & {
	RemoteSignal: RemoteSignal,
	OnInvoke: func,
	TimeoutDuration: number
}

local identifiers: {[Player]: number} = {}
local promises: {[Player]: {Promise}} = {}

local function onPlayerRemoving(player: Player)
	identifiers[player] = nil
	promises[player] = nil
end

local function onPlayerAdded(player: Player)
	identifiers[player] = 0
	promises[player] = {}
end

local function getNextId(player: Player)
	local identifier = identifiers[player]
	if not identifier then
		return
	end
	identifiers[player] += 1
	return identifiers[player]
end

function RemoteFunctionServer.new(name: string, remoteSignal: RemoteSignal, timeoutDuration: number?): RemoteFunction
	local self = setmetatable({} :: RemoteFunction, RemoteFunctionServer)
	self.TimeoutDuration = timeoutDuration
	self.RemoteSignal = remoteSignal
	self.RemoteSignal:Connect(function(player: Player, id: number, ...: any)
		local onInvoke = self.OnInvoke
		if onInvoke then
			self.RemoteSignal:Fire(player, id, pcall(onInvoke, player, ...))
			return
		end
		local playerPromises = promises[player]
		if not playerPromises then
			return
		end
		local promise = playerPromises[id]
		if not promise then
			return
		end
		local args = {...}
		local success = table.remove(args, 1)
		if promise:GetStatus() == "Pending" then
			promise:_forceResolve(success, table.unpack(args))
		end
		playerPromises[id] = nil
	end)
	return self
end

function RemoteFunctionServer:Invoke(player: Player, ...: any): Promise
	local id = getNextId(player)
	if not id then
		error(player.Name .. " does not exist!")
	end
	self.RemoteSignal:Fire(player, id, ...)
	local promise = Promise.new(function(resolve: func, reject: func, onCancel: func)
		local connection = player:GetPropertyChangedSignal("Parent"):Connect(function()
			reject(player.Name, "has left the game!")
		end)
		local timeoutThread
		local timeoutDuration = self.TimeoutDuration
		if timeoutDuration then
			timeoutThread = coroutine.create(function()
				task.wait(timeoutDuration)
				reject(player.Name .. "'s request has timed out!")
			end)
			coroutine.resume(timeoutThread)
		end
		onCancel(function()
			connection:Disconnect()
			if timeoutThread then
				coroutine.close(timeoutThread)
			end
		end)
		coroutine.yield()
	end)
	local playerPromises = promises[player]
	playerPromises[id] = promise
	return promise
end

function RemoteFunctionServer:Destroy()
	self.RemoteSignal:Destroy()
end

Players.PlayerRemoving:Connect(onPlayerRemoving)
Players.PlayerAdded:Connect(onPlayerAdded)

for i, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

return RemoteFunctionServer