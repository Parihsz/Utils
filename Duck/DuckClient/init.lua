--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(script.Parent.Parent:WaitForChild("Signal"))
local Promise = require(script.Parent.Parent:WaitForChild("Promise"))
local DuckShared = require(script.Parent:WaitForChild("DuckShared"))
local RemoteSignal = require(script.Parent:WaitForChild("RemoteSignal"):WaitForChild("RemoteSignalClient"))
local RemoteFunction = require(script.Parent:WaitForChild("RemoteFunction"):WaitForChild("RemoteFunctionClient"))

local DuckClient = {}
DuckClient.__index = DuckClient

type Promise = Promise.Promise
type RemoteSignal = RemoteSignal.RemoteSignal
type RemoteFunction = RemoteFunction.RemoteFunction

type frames = number
type callback = (...any) -> (...any)

type playerPacket = {
	Names: {string},
	Data: {any},
	Size: number
}

local dispatchCycle = 1

local currentCycle = 1
local compressionFunction

local remoteSignals = require(script.Parent:WaitForChild("RemoteSignals"))

local duckRemote: RemoteEvent

local playerPacket = require(script:WaitForChild("PlayerPacket"))

local function dispatchPackets()
	if #playerPacket.Names < 1 then
		return
	end
	duckRemote:FireServer(playerPacket)
	table.clear(playerPacket.Names)
	table.clear(playerPacket.Data)
	playerPacket.Size = 0
end

local function runCallbacks(callbacks: {callback}, ...: any)
	for i, callback in callbacks do
		local thread = coroutine.create(callback)
		coroutine.resume(thread, ...)
	end
end

local function onIncomingReplication(packet: playerPacket)
	local data = packet.Data
	local names = packet.Names
	for i, name in names do
		local remoteSignal = remoteSignals[name]
		if not remoteSignal then
			continue
		end
		local callbacks = remoteSignal.Callbacks
		runCallbacks(callbacks, table.unpack(data[i]))
	end
end

DuckClient.CreateRemoteSignal = DuckShared.CreateRemoteSignal :: (name: string) -> (RemoteSignal?)
DuckClient.GetRemoteSignal = DuckShared.GetRemoteSignal :: (name: string) -> (RemoteSignal?)
DuckClient.DestroyRemoteSignal = DuckShared.DestroyRemoteSignal :: (name: string) -> (nil)
DuckClient.CreateRemoteFunction = DuckShared.CreateRemoteFunction :: (name: string, timeoutDuration: number?) -> (RemoteFunction?)

function DuckClient.PrintPacket()
	print(playerPacket)
end

function DuckClient.Initialize()
	duckRemote = ReplicatedStorage:WaitForChild("DuckRemote")
	RunService.Heartbeat:Connect(dispatchPackets)
	duckRemote.OnClientEvent:Connect(onIncomingReplication)
end

return DuckClient