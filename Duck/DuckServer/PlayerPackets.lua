local playerPackets: {[Player]: playerPacket} = {}

export type playerPacket = {
	Names: {string},
	Data: {any},
	Size: number
}

return playerPackets