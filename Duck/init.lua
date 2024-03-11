--[[
TODO:
- Add string/table compression
- Add rate limit per keys
- Convert identifiers to integers
]]
local RunService = game:GetService("RunService")

local function packString(data: string)
	local length = string.len(data)
	return string.pack("<Hz", length, data)
end

local function unpackString(data: string)
	local unpackedData = {string.unpack("<Hz", data)}
	return unpackedData[2]
end

if RunService:IsServer() then
	return require(script:WaitForChild("DuckServer"))
else
	return require(script:WaitForChild("DuckClient"))
end
