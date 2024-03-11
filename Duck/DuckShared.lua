local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RemoteSignal = require(script.Parent:WaitForChild("RemoteSignal"))
local RemoteFunction = require(script.Parent:WaitForChild("RemoteFunction"))

local DuckShared = {}

local remoteSignals = require(script.Parent:WaitForChild("RemoteSignals"))

local remoteFunctions = {}

function DuckShared.CreateRemoteSignal(name: string)
	local remoteSignal = remoteSignals[name]
	if remoteSignal then
		warn("A remote signal with the name", name, "already exists!")
		return
	end
	remoteSignal = RemoteSignal.new(name)
	remoteSignals[name] = remoteSignal
	return remoteSignal
end

function DuckShared.GetRemoteSignal(name: string)
	local remoteSignal = remoteSignals[name]
	if not remoteSignal then
		warn("Remote signal with", name, "does not exist!")
		return
	end
	return remoteSignal
end

function DuckShared.DestroyRemoteSignal(name: string)
	if not remoteSignals[name] then
		warn("This remote signal does not exist!")
		return
	end
	remoteSignals[name] = nil
end

function DuckShared.CreateRemoteFunction(name: string, timeoutDuration: number?)
	if remoteSignals[name] then
		warn("A remote signal with the name", name, "already exists!")
		return
	end
	local remoteSignal = RemoteSignal.new(name)
	remoteSignals[name] = remoteSignal
	local remoteFunction = RemoteFunction.new(name, remoteSignal, timeoutDuration)
	return remoteFunction
end

return DuckShared