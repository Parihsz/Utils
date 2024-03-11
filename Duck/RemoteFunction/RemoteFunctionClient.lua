local Promise = require(script.Parent.Parent.Parent:WaitForChild("Promise"))
local RemoteSignal = require(script.Parent.Parent:WaitForChild("RemoteSignal"):WaitForChild("RemoteSignalClient"))

local RemoteFunctionClient = {}
RemoteFunctionClient.__index= RemoteFunctionClient

type Promise = Promise.Promise
type RemoteSignal = RemoteSignal.RemoteSignal

type func = (...any) -> (...any)

export type RemoteFunction = typeof(setmetatable({}, RemoteFunctionClient)) & {
	RemoteSignal: RemoteSignal,
	OnInvoke: func,
	TimeoutDuration: number
}

local id = 0

local promises: {Promise} = {}

local function getNextId()
	id += 1
	return id
end

function RemoteFunctionClient.new(name: string, remoteSignal: RemoteSignal, timeoutDuration: number?): RemoteFunction
	local self = setmetatable({} :: RemoteFunction, RemoteFunctionClient)
	self.TimeoutDuration = timeoutDuration
	self.RemoteSignal = remoteSignal
	self.RemoteSignal:Connect(function(id: number, ...: any)
		local onInvoke = self.OnInvoke
		if onInvoke then
			self.RemoteSignal:Fire(id, pcall(onInvoke, ...))
			return
		end
		local promise = promises[id]
		if not promise then
			return
		end
		local args = {...}
		local success = table.remove(args, 1)
		if promise:GetStatus() == "Pending" then
			promise:_forceResolve(success, table.unpack(args))
		end
		promises[id] = nil
	end)
	return self
end

function RemoteFunctionClient:Invoke(...: any): Promise
	local id = getNextId()
	self.RemoteSignal:Fire(id, ...)
	local promise = Promise.new(function(resolve: func, reject: func, onCancel: func)
		local timeoutThread
		local timeoutDuration = self.TimeoutDuration
		if timeoutDuration then
			timeoutThread = coroutine.create(function()
				task.wait(timeoutDuration)
				reject("Request has timed out!")
			end)
			coroutine.resume(timeoutThread)
		end
		onCancel(function()
			if timeoutThread then
				coroutine.close(timeoutThread)
			end
		end)
		coroutine.yield()
	end)
	promises[id] = promise
	return promise
end

function RemoteFunctionClient:Destroy()
	self.RemoteSignal:Destroy()
end

return RemoteFunctionClient