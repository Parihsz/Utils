local Counter = {}
Counter.__index = Counter

export type Counter = typeof(setmetatable({}, Counter)) & {
	Value: number,
	DefaultValue: number,
	MaxValue: number?,
	ResetTime: seconds?,
	_lastIncremented: number
}

type seconds = number

local function canReset(lastIncremented: number, resetTime: seconds?, currentTime: number): boolean
	if not resetTime then
		return false
	end
	if currentTime - lastIncremented > resetTime then
		return true
	end
	return false
end

function Counter.new(defaultValue: number, maxValue: number, resetTime: seconds?): Counter
	local self = setmetatable({} :: Counter, Counter)
	self.Value = defaultValue
	self.DefaultValue = defaultValue
	self.MaxValue = maxValue
	self.ResetTime = resetTime
	self._lastIncremented = 0
	return self
end

function Counter:Reset()
	self.Value = self.DefaultValue
	self._lastIncremented = os.time()
end

function Counter:Increment(amount: number?)
	if self:AttemptReset() then
		return
	end
	if not amount then
		amount = 1
	end
	self.Value += amount
	if self.Value > self.MaxValue then
		self.Value = self.DefaultValue
	end
	self._lastIncremented = os.time()
end

function Counter:Decrement(amount: number?)
	if self:AttemptReset() then
		return
	end
	if not amount then
		amount = 1
	end
	self.Value -= amount
	if self.Value < self.DefaultValue then
		self.Value = self.MaxValue
	end
	self._lastIncremented = os.time()
end

function Counter:AttemptReset(): boolean
	if canReset(self._lastIncremented, self.ResetTime, os.time()) then
		self:Reset()
		return true
	end
	return false
end

return Counter