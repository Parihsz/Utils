-- This is unfinished ATM
local Serializer = {}

local types = {
	[1] = "Axes",
	[2] = "BrickColor",
	[3] = "CatalogSearchParams",
	[4] = "CFrame",
	[5] = "Color3",
	[6] = "ColorSequence",
	[7] = "ColorSequenceKeypoint",
	[8] = "Content",
	[9] = "DataTime",
	[10] = "DockWidgetPluginGuiInfo",
	[11] = "Enum",
	[12] = "EnumItem",
	[13] = "Enums",
	[14] = "Faces",
	[15] = "FloatCurveKey",
	[16] = "Font",
	[17] = "Instance",
	[18] = "NumberRange",
	[19] = "NumberSequence",
	[20] = "NumberSequenceKeypoint",
	[21] = "OverlapParams",
	[22] = "PathWaypoint",
	[23] = "PhysicalProperties",
	[24] = "Random",
	[25] = "Ray",
	[26] = "RaycastParams",
	[27] = "RaycastResult",
	[28] = "RBXScriptConnection",
	[29] = "RBXScriptSignal",
	[30] = "Rect",
	[31] = "Region3",
	[32] = "Region3int16",
	[33] = "SharedTable",
	[34] = "TweenInfo",
	[35] = "Udim2",
	[36] = "Vector2",
	[37] = "Vector2int16",
	[38] = "Vector3",
	[39] = "Vector3int16",
}
local invertedTypes = {
	["Axes"] = 1,
	["BrickColor"] = 2,
	["CatalogSearchParams"] = 3,
	["CFrame"] = 4,
	["Color3"] = 5,
	["ColorSequence"] = 6,
	["ColorSequenceKeypoint"] = 7,
	["Content"] = 8,
	["DataTime"] = 9,
	["DockWidgetPluginGuiInfo"] = 10,
	["Enum"] = 11,
	["EnumItem"] = 12,
	["Enums"] = 13,
	["Faces"] = 14,
	["FloatCurveKey"] = 15,
	["Font"] = 16,
	["Instance"] = 17,
	["NumberRange"] = 18,
	["NumberSequence"] = 19,
	["NumberSequenceKeypoint"] = 20,
	["OverlapParams"] = 21,
	["PathWaypoint"] = 22,
	["PhysicalProperties"] = 23,
	["Random"] = 24,
	["Ray"] = 25,
	["RaycastParams"] = 26,
	["RaycastResult"] = 27,
	["RBXScriptConnection"] = 28,
	["RBXScriptSignal"] = 29,
	["Rect"] = 30,
	["Region3"] = 31,
	["Region3int16"] = 32,
	["SharedTable"] = 33,
	["TweenInfo"] = 34,
	["Udim2"] = 35,
	["Vector2"] = 36,
	["Vector2int16"] = 37,
	["Vector3"] = 38,
	["Vector3int16"] = 39,
}

local encodeOptions = {
	["Vector3"] = function(v)
		return {v.X, v.Y, v.Z}
	end,
	["CFrame"] = function(v)
		local pos = v.Position
		local x, y, z = v:ToEulerAnglesXYZ()
		return {pos.X, pos.Y, pos.Z, x, y, z}
	end,
}

local decodeOptions = {
	["Vector3"] = function(v)
		return Vector3.new(v[2], v[3], v[4])
	end,
	["CFrame"] = function(v)
		local position = Vector3.new(v[2], v[3], v[4])
		return CFrame.new(position) * CFrame.Angles(v[5], v[6], v[7])
	end,
}

local function typeToNumber(typeName)
	return invertedTypes[typeName]
end

local function numberToType(number)
	return types[number]
end

function Serializer.Encode(data)
	if not data then
		warn("Cannot encode nil!")
		return nil
	end
	local dataType = typeof(data)
	local encodeFunction = encodeOptions[dataType]
	if not encodeFunction then
		warn("Cannot encode", dataType)
		return nil
	end
	local encodedData = encodeFunction(data)
	table.insert(encodedData, 1, typeToNumber(dataType))
	return encodedData
end

function Serializer.Decode(data)
	if not data then
		warn("Cannot decode nil!")
		return nil
	end
	local dataType = numberToType(data[1])
	local decodeFunction = decodeOptions[dataType]
	if not decodeFunction then
		warn("Cannot decode", dataType)
		return nil
	end
	local decodedData = decodeFunction(data)
	return decodedData
end

function Serializer.CanSerialize(data)
	local dataType = typeof(data)
	if encodeOptions[dataType] and decodeOptions[dataType] then
		return true
	end
	return false
end

return Serializer