local Enums = {}
Enums.__index = Enums

local EnumObject = {}
EnumObject.__index = EnumObject

export type Enums = typeof(setmetatable({}, Enums)) & {
	_name: string,
	_parent: Enums?
}

export type EnumObject = typeof(setmetatable({}, EnumObject)) & {
	_name: string,
	_parent: Enums
}

local function enumify(contents: {string | Enums}): Enums
	local enumObjects = {} :: Enums
	for i, v in contents do
		local objectType = typeof(v)
		if objectType == "string" then
			enumObjects[v] = EnumObject.new(v, enumObjects)
		elseif objectType == "table" then
			v._parent = enumObjects
			enumObjects[v._name] = v
		end
	end
	return enumObjects
end

function Enums.new(name: string, contents: {string | Enums}): Enums
	local self = setmetatable(enumify(contents) :: Enums, Enums)
	self._name = name
	return self
end

Enums.__tostring = function(self)
	local parent = self._parent
	if parent then
		return tostring(parent) .. "." .. self._name
	end
	return "Enums." .. self._name
end

function EnumObject.new(name: string, parent: Enums): EnumObject
	local self = setmetatable({} :: EnumObject, EnumObject)
	self._name = name
	self._parent = parent
	return self
end

EnumObject.__tostring = function(self)
	return tostring(self._parent) .. "." .. self._name
end


return Enums

--[[
OLD
local Enums = {}
Enums.__index = Enums
Enums.ClassName = "Enums"

local EnumObject = {}
EnumObject.__index = EnumObject
EnumObject.ClassName = "EnumObject"
EnumObject.__tostring = function(self: EnumObject)
	return self:GetFullName()
end

export type Enums = typeof(setmetatable({}, Enums)) & {
	
}

export type EnumObject = typeof(setmetatable({}, EnumObject)) & {
	
}

local function createEnum(enum: string | Enums, parent: Enums)
	local enumType = typeof(enum)
	if enumType == "string" then
		return EnumObject.new(enum :: string, parent)
	elseif enumType == "table" then
		local enums = enum :: Enums
		enums._parent = parent
		return enums
	else
		warn("Type", enumType, "is not compatible!")
	end
end

local function createEnumTable(enumTable: {string | Enums})
	local newTable = {} :: Enums
	for i, enum in enumTable do
		local enumType = typeof(enum)
		if enumType == "string" then
			newTable[enum] = EnumObject.new(enum, newTable)
		elseif enumType == "table" then
			enum._parent = newTable
			newTable[enum._name] = enum
		else
			warn("Type", enumType, "is not compatible!")
		end
	end
	return newTable
end

function Enums.new(name: string, enumTable: {string | Enums}): Enums
	local self = setmetatable({createEnumTable(enumTable)} :: Enums, Enums)
	self._name = name
	return self
end

function Enums:AddNewEnum(enum: string | Enums)
	local enumType = typeof(enum)
	if enumType == "string" then
		self[enum] = EnumObject.new(enum :: string, self)
	elseif enumType == "table" then
		self[enum._name] = enum :: Enums
	else
		warn("Type", enumType, "is not compatible!")
	end
end

function EnumObject.new(name: string, parent: Enums): EnumObject
	local self = setmetatable({} :: EnumObject, EnumObject)
	self._name = name
	self._parent = parent
	return self
end

function EnumObject:GetFullName()
	return self
end

return Enums
]]