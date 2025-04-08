local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self.listeners = {}  -- Store the listeners
	return self
end

-- Connect a listener to the signal
function Signal:Connect(callback)
	table.insert(self.listeners, callback)  -- Add listener to the list
	return callback  -- Return the listener callback for potential removal later
end

-- Disconnect a listener from the signal
function Signal:Disconnect(callback)
	for i, listener in ipairs(self.listeners) do
		if listener == callback then
			table.remove(self.listeners, i)  -- Remove the listener
			break
		end
	end
end

-- Fire the signal, calling all listeners in the order they were added
function Signal:Fire(...)
	for _, listener in ipairs(self.listeners) do
		listener(...)  -- Call each listener with the provided arguments
	end
end

-- Wait for the signal to be fired
function Signal:Wait()
	local thread = coroutine.running()
	self:Connect(function(...)
		coroutine.resume(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
