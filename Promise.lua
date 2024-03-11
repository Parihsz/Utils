--!strict
local Promise = {}
Promise.__index = Promise
Promise.ClassName = "Promise"

export type func = (...any) -> (...any)

export type Promise = typeof(setmetatable({}, Promise)) & {
	YieldingThreads: {thread},
	LastPromise: Promise,
	Thread: thread,
	NextThread: thread,
	Success: boolean,
	Args: any | {any}
}

local function attemptUnpackArgs(args: any): ...any | any
	if typeof(args) == "table" then
		return table.unpack(args)
	end
	return args
end

local function runCallback(callback: func, args: any): (boolean, string | any)
	local success, returnValue = pcall(function()
		return {callback(attemptUnpackArgs(args))}
	end)
	return success, returnValue
end

local function resumeYieldingThreads(pendingPromise: Promise) -- This resumes threads that are waiting for promise results
	local yieldingThreads = pendingPromise.YieldingThreads
	if yieldingThreads then
		for i, yieldingThread in yieldingThreads do
			coroutine.resume(yieldingThread)
		end
	end
end

--[[
This resumes the next promise that is queued up once the current promise is finished running. It only resumes the next thread if
the current thread yields.
]]
local function processNextThread(pendingPromise: Promise)
	local nextThread = pendingPromise.NextThread
	if nextThread then
		coroutine.resume(nextThread)
	end
end

--[[
This queue's up a promise that always runs a callback regardless of the success of the previous promise. It's used in Promise:Finally
and Promise.new
]]
local function queuePromise(pendingPromise: Promise, callback: func, oldPromise: Promise)
	pendingPromise.Thread = coroutine.create(function()
		local args = oldPromise.Args
		pendingPromise.Success, pendingPromise.Args = runCallback(callback, args)
		processNextThread(pendingPromise)
		resumeYieldingThreads(pendingPromise)
	end)
end

local function queueNewPromise(pendingPromise: Promise, callback: func)
	pendingPromise.Thread = coroutine.create(function()
		local cancelCallbackUp
		local function resume()
			if cancelCallbackUp then
				local cancelThread = coroutine.create(cancelCallbackUp)
				coroutine.resume(cancelThread)
			end
			processNextThread(pendingPromise)
			resumeYieldingThreads(pendingPromise)
		end
		local function cleanup(success: boolean, ...: any)
			if pendingPromise.Success ~= nil then
				return
			end
			pendingPromise.Success = success
			pendingPromise.Args = {...}
			local thread = pendingPromise.Thread
			if coroutine.status(thread) == "suspended" then
				coroutine.close(thread)
			end
			resume()
		end
		local function resolve(...: any)
			cleanup(true, ...)
		end
		local function reject(...: any)
			cleanup(false, ...)
		end
		local function onCancel(cancelCallback: func)
			cancelCallbackUp = cancelCallback
		end
		local success, args = runCallback(callback, {resolve, reject, onCancel})
		-- This returns if the promise has already been resolved or rejected
		if pendingPromise.Success ~= nil then
			return
		end
		pendingPromise.Success, pendingPromise.Args = success, args
		resume()
	end)
end

--[[
This queue's up a promise that runs the callback if the success of the previous promise is equal to the success parameter. Otherwise, it
copies the results of the old promise to the current promise. For example, Promise:Catch passes false for the success parameter, 
because it runs only if the previous promise has errored. While Promise:Then only runs if the old promise has succeeded.
]]
local function queueSuccessPromise(pendingPromise: Promise, callback: func, oldPromise: Promise, success: boolean)
	pendingPromise.Thread = coroutine.create(function()
		if oldPromise.Success == success then
			local args = oldPromise.Args
			pendingPromise.Success, pendingPromise.Args = runCallback(callback, args)
		else
			pendingPromise.Success = oldPromise.Success
			pendingPromise.Args = oldPromise.Args
		end
		processNextThread(pendingPromise)
		resumeYieldingThreads(pendingPromise)
	end)
end

local function createPendingPromise(oldPromise: Promise): Promise
	local pendingPromise = setmetatable({} :: Promise, Promise)
	pendingPromise.LastPromise = oldPromise
	pendingPromise.YieldingThreads = {}
	return pendingPromise
end

--[[
This queue's up the next thread to run. It checks if the old promise is yielding, and if it is, it sets the nextThread property of the old promise
to the current thread to run once the old promise is finished executing. If the old thread is not yielding, we know that it has finished executing
and therefore we run the current promise's thread.
]]
local function queueNextThread(pendingPromise: Promise, oldPromise: Promise)
	local oldThread = oldPromise.Thread
	if typeof(oldThread) == "thread" and coroutine.status(oldThread) == "suspended" then
		-- This tells the old promise to run this promise once the old thread finished yielding
		oldPromise.NextThread = pendingPromise.Thread
	else
		coroutine.resume(pendingPromise.Thread)
	end
end

function Promise.new(callback: (resolve: func, reject: func, onCancel: func) -> ()): Promise
	local self = setmetatable({} :: Promise, Promise)
	self.YieldingThreads = {}
	queueNewPromise(self, callback)
	coroutine.resume(self.Thread)
	return self
end

function Promise.Race(promises: {Promise}): any
	local newPromises = {}
	return Promise.new(function(resolve: func, reject: func, onCancel: func)
		onCancel(function()
			for i, promise in promises do
				promise:Close()
			end
			for i, newPromise in ipairs(newPromises) do
				newPromise:Close()
			end
		end)
		for i, promise in promises do
			newPromises[i] = promise:Then(resolve):Catch(reject)
		end
		coroutine.yield()
	end)
end

--[[
function Promise.Race(promises: {Promise}): any
	local upValue
	local thread = coroutine.running()
	local newPromises = {}
	for i, promise in promises do
		newPromises[i] = promise:Then(function(...: any)
			local currentPromise = newPromises[i]
			upValue = {...}
			for i, newPromise in newPromises do
				if newPromise ~= currentPromise then
					newPromise:Close()
				end
			end
			coroutine.resume(thread)
		end)
		if newPromises[i]:GetStatus() == "Complete" then
			break
		end
	end
	if not upValue then
		coroutine.yield()
	end
	return table.unpack(upValue)
end

]]

function Promise:_forceResolve(success: boolean, ...: any)
	self.Success = success
	self.Args = {...}
	processNextThread(self :: Promise)
	resumeYieldingThreads(self :: Promise)
end

function Promise:Finally(callback: func): Promise
	local pendingPromise = createPendingPromise(self)
	queuePromise(pendingPromise, callback, self)
	queueNextThread(pendingPromise, self)
	return pendingPromise
end

function Promise:Catch(callback: func): Promise
	local pendingPromise = createPendingPromise(self)
	queueSuccessPromise(pendingPromise, callback, self, false)
	queueNextThread(pendingPromise, self)
	return pendingPromise
end

function Promise:Then(callback: func): Promise
	local pendingPromise = createPendingPromise(self)
	queueSuccessPromise(pendingPromise, callback, self, true)
	queueNextThread(pendingPromise, self)
	return pendingPromise
end

function Promise:Await(): Promise
	local pendingPromise = createPendingPromise(self)
	local oldThread: thread = self.Thread
	if coroutine.status(oldThread) == "suspended" then
		local runningThread = coroutine.running()
		pendingPromise.Thread = coroutine.create(function()
			pendingPromise.Args = self.Args
			resumeYieldingThreads(pendingPromise)
			coroutine.resume(runningThread)
		end)
		self.NextThread = pendingPromise.Thread
		coroutine.yield()
	else
		resumeYieldingThreads(pendingPromise)
	end
	return pendingPromise
end

function Promise:Close()
	local currentPromise = self
	-- Looping backwards from the last promise to the first promise
	while currentPromise do
		local thread = currentPromise.Thread
		-- We return because we know that all the previous threads have finished yielding
		if coroutine.status(thread) ~= "suspended" then
			return
		end
		coroutine.close(thread)
		currentPromise = currentPromise.LastPromise
	end
end

--[[
This returns the return value of the last promise once the chain has finished running
]]
function Promise:GetResultsAsync(): ...any
	if coroutine.status(self.Thread) ~= "suspended" then
		return attemptUnpackArgs(self.Args)
	end
	table.insert(self.YieldingThreads, coroutine.running())
	coroutine.yield()
	return attemptUnpackArgs(self.Args)
end

function Promise:GetResults(): ...any
	if typeof(self.Thread) == "thread" and coroutine.status(self.Thread) == "suspended" then
		warn("Promise is still active, no value returned!")
		return nil
	end
	return attemptUnpackArgs(self.Args)
end

function Promise:GetErrorMesssagesAsync()
	if typeof(self.Thread) == "thread" and coroutine.status(self.Thread) == "suspended" then
		table.insert(self.YieldingThreads, coroutine.running())
	end
	local errorMessages = {}
	local currentPromise = self
	while currentPromise do
		if not currentPromise.Success then
			table.insert(errorMessages, currentPromise.Args)
		end
		currentPromise = currentPromise.LastPromise
	end
	return errorMessages
end

function Promise:GetStatus(): "Pending" | "Complete"
	if self.Success ~= nil then
		return "Complete"
	end
	return "Pending"
end

return Promise



--[[
OLD
local Promise = {}
Promise.__index = Promise
Promise.ClassName = "Promise"

local ResolvedPromise = setmetatable({}, Promise)
ResolvedPromise.__index = ResolvedPromise

local RejectedPromise = setmetatable({}, Promise)
RejectedPromise.__index = RejectedPromise

local function packArgs(...)
	local args = {...}
	print(args)
	local success = table.remove(args, 1)
	return success, args
end

local function getPromise(callback: any, passedArgs: any, callerThread: thread)
	local errorMessageUp
	local success, args = xpcall(function()
		return callback(passedArgs)
	end, function(errorMessage)
		errorMessageUp = errorMessage
	end)
	if success then
		return ResolvedPromise.new(args, callerThread)
	else
		return RejectedPromise.new(errorMessageUp, callerThread)
	end
end

function Promise.new(callback: any)
	local self = setmetatable({}, Promise)
	local callerThread = coroutine.running()
	return getPromise(callback, nil, callerThread)
end

function Promise:Finally(callback: any)
	return getPromise(callback, self.Args or self.ErrorMessage, self.CallerThread)
end

function Promise:Await()
	return getPromise(function()
		
	end)
end

function ResolvedPromise.new(args: any, callerThread: thread)
	local self = setmetatable({}, ResolvedPromise)
	self.Args = args
	self.CallerThead = callerThread
	return self
end

function ResolvedPromise:Then(callback: any)
	return getPromise(callback, self.Args)
end

function ResolvedPromise:Catch(callback: any)
	return self
end

function RejectedPromise.new(errorMessage: string, callerThread: thread)
	local self = setmetatable({}, RejectedPromise)
	self.ErrorMessage = errorMessage
	self.CallerThread = callerThread
	return self
end

function RejectedPromise:Then(callback: any)
	return self
end

function RejectedPromise:Catch(callback: any)
	return getPromise(callback, self.ErrorMessage)
end

return Promise
]]