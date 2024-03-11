local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Signal = require(script.Parent.Parent.Signal)
local Promise = require(script.Parent.Parent.Promise)
local DuckShared = require(script.Parent.DuckShared)
local RemoteSignal = require(script.Parent.RemoteSignal.RemoteSignalServer)
local RemoteFunction = require(script.Parent.RemoteFunction.RemoteFunctionServer)
local RateLimit = require(script.RateLimit)

local DuckServer = {}
DuckServer.__index = DuckServer

type Promise = Promise.Promise
type RemoteSignal = RemoteSignal.RemoteSignal
type RemoteFunction = RemoteFunction.RemoteFunction

type dispatchTo = "All" | "AllExcept" | "Players"
type frames = number
type callback = (Player, ...any) -> (...any)

local maxPacketsCycle = 1000

local remoteSignals = require(script.Parent:WaitForChild("RemoteSignals"))

local duckRemote: RemoteEvent

local playerPackets = require(script:WaitForChild("PlayerPackets"))

DuckServer.RateLimitHit = Signal.new()

local function onPlayerAdded(player: Player)
	playerPackets[player] = {
		Names = {},
		Data = {},
		Size = 0
	}
end

local function onPlayerRemoving(player: Player)
	playerPackets[player] = nil
end

local function runCallbacks(callbacks: {callback}, player: Player, ...: any)
	for i, callback in callbacks do
		local thread = coroutine.create(callback)
		coroutine.resume(thread, player, ...)
	end
end

local function onIncomingReplication(player: Player, packet: playerPackets.playerPacket)
	local data = packet.Data
	local names = packet.Names
	local numberOfPackets = 0
	for i, name in names do
		numberOfPackets += 1
		local rateLimitHit = numberOfPackets > maxPacketsCycle
		if rateLimitHit then
			warn(player, "has been rate limited, number of packets sent:", numberOfPackets)
			DuckServer.RateLimitHit:Fire(player, numberOfPackets)
			return
		end
		local remoteSignal = remoteSignals[name]
		if not remoteSignal then
			continue
		end
		local callbacks = remoteSignal.Callbacks
		runCallbacks(callbacks, player, table.unpack(data[i]))
	end
end

local function dispatchPackets()
	local players = Players:GetPlayers()
	for i, player in players do
		-- Player check
		local packet: playerPackets.playerPacket = playerPackets[player]
		if not packet then
			warn("Packet does not exist!")
			continue
		end
		local packetNames = packet.Names
		local packetData = packet.Data
		if #packetNames < 1 then
			continue
		end
		if not packet then
			warn(player.Name, "packet does not exist!")
			continue
		end
		duckRemote:FireClient(player, packet)
		table.clear(packetNames)
		table.clear(packetData)
		packet.Size = 0
	end
end

DuckServer.CreateRemoteSignal = DuckShared.CreateRemoteSignal :: (name: string) -> (RemoteSignal?)
DuckServer.GetRemoteSignal = DuckShared.GetRemoteSignal :: (name: string) -> (RemoteSignal?)
DuckServer.DestroyRemoteSignal = DuckShared.DestroyRemoteSignal :: (name: string) -> (nil)
DuckServer.CreateRemoteFunction = DuckShared.CreateRemoteFunction :: (name: string, timeoutDuration: number?) -> (RemoteFunction)

function DuckServer.PrintAllPackets()
	print(playerPackets)
end

function DuckServer.Initialize()
	duckRemote = Instance.new("RemoteEvent")
	duckRemote.Parent = ReplicatedStorage
	duckRemote.Name = "DuckRemote"
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	RunService.Heartbeat:Connect(dispatchPackets)
	duckRemote.OnServerEvent:Connect(onIncomingReplication)
end

function DuckServer.SetGlobalRateLimit(callsPerFrame: number)
	maxPacketsCycle = callsPerFrame
end

return DuckServer