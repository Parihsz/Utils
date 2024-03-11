local Players = game:GetService("Players")

local RemoteSignalShared = require(script.Parent.RemoteSignalShared)

local RemoteSignalServer = {}
RemoteSignalServer.__index = RemoteSignalServer

type callback = RemoteSignalShared.callback

type dispatchTo = "All" | "AllExcept" | "Select"

export type RemoteSignal = RemoteSignalShared.RemoteSignal & typeof(setmetatable({}, RemoteSignalServer))

local playerPackets = require(script.Parent.Parent.DuckServer.PlayerPackets)

local function insertPacket(player: Player, name: string, value: any)
	local packet = playerPackets[player]
	if not packet then
		return
	end
	packet.Size += 1
	local size = packet.Size
	packet.Names[size] = name
	packet.Data[size] = value
end

local function queue(name: string, value: {any}, dispatchTo: dispatchTo, players: Player? | {Player}?)
	if dispatchTo == "All" then
		for player, packet in playerPackets do
			insertPacket(player, name, value)
		end
		return
	end
	if dispatchTo == "Select" then
		if typeof(players) == "table" then
			for i, player in players :: {Player} do
				insertPacket(player, name, value)
			end
			return
		end
		insertPacket(players :: Player, name, value)
		return
	end
	if dispatchTo == "AllExcept" then
		local allPlayers = Players:GetPlayers()
		if typeof(players) == "table" then
			for i, player in players do
				local index = table.find(allPlayers, player)
				if index then
					table.remove(allPlayers, index)
				end
			end
		else
			local index = table.find(allPlayers, players)
			if index then
				table.remove(allPlayers, index)
			end
		end
		for i, player in allPlayers do
			insertPacket(player, name, value)
		end
		return
	end
end

RemoteSignalServer.Connect = RemoteSignalShared.Connect
RemoteSignalServer.Once = RemoteSignalShared.Once
RemoteSignalServer.Wait = RemoteSignalShared.Wait
RemoteSignalServer.Destroy = RemoteSignalShared.Destroy
RemoteSignalServer.DisconnectAll = RemoteSignalShared.DisconnectAll

function RemoteSignalServer.new(name: string): RemoteSignal
	local self = setmetatable({} :: RemoteSignal, RemoteSignalServer)
	self.Name = name
	self.Callbacks = {}
	return self
end

function RemoteSignalServer:Fire(players: Player | {Player}, ...: any)
	queue(self.Name, {...}, "Select", players)
end

function RemoteSignalServer:FireAll(...: any)
	queue(self.Name, {...}, "All")
end

function RemoteSignalServer:FireAllExcept(players: Player | {Player}, ...: any)
	queue(self.Name, {...}, "AllExcept", players)
end

return RemoteSignalServer