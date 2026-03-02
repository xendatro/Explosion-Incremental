local ExampleClass = {}
ExampleClass.__index = ExampleClass


function ExampleClass.new(part: BasePart)
	local self = setmetatable({}, ExampleClass)

	self.Part = part

	print(self.Part)

	return self
end

function ExampleClass:Touched(hit)
	print(hit)
end

function ExampleClass:Destroy()
	self.Part:Destroy()
	for _, connection in self.Connections do
		connection:Disconnect()
	end
end

return ExampleClass