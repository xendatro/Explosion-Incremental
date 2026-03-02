return function(signal: RBXScriptSignal, n: number)
	local current = coroutine.running()
	local resolved = false

	local c1 = coroutine.create(function()
		local v = table.pack(signal:Wait())
		if not resolved then
			resolved = true
			coroutine.resume(current, v)
		end
	end)

	local c2 = coroutine.create(function()
		task.wait(n)
		if not resolved then
			resolved = true
			coroutine.resume(current)
		end
	end)

	coroutine.resume(c1)
	coroutine.resume(c2)
	local v = coroutine.yield()

	if v == nil then
		return false
	else
		return true, table.unpack(v)
	end
end